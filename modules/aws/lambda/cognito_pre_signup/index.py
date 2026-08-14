"""Cognito Pre Sign-up trigger: unique email + link Google SSO to existing users.

Behaviors:
- PreSignUp_SignUp: reject if email already belongs to a user (unique email).
- PreSignUp_ExternalProvider (e.g. Google): if email matches an existing user,
  AdminLinkProviderForUser then abort creating a second profile. The next Google
  sign-in authenticates as the linked (original) user. Cognito `sub` stays the
  destination user's sub — same identity for the app.
"""

from __future__ import annotations

import logging
import os

import boto3

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

cognito = boto3.client("cognito-idp")
sns = boto3.client("sns")

NEW_USER_SNS_TOPIC_ARN = os.environ.get("NEW_USER_SNS_TOPIC_ARN")


def _notify_new_user(email: str, trigger: str) -> None:
    if not NEW_USER_SNS_TOPIC_ARN:
        return
    try:
        sns.publish(
            TopicArn=NEW_USER_SNS_TOPIC_ARN,
            Subject="New Cognito user",
            Message=f"New user signed up: {email} (via {trigger})",
        )
    except Exception:
        LOG.exception("failed to publish new-user notification")


def _find_users_by_email(user_pool_id: str, email: str) -> list[dict]:
    # Cognito ListUsers filter requires exact match; emails are compared as stored.
    resp = cognito.list_users(
        UserPoolId=user_pool_id,
        Filter=f'email = "{email}"',
        Limit=10,
    )
    return resp.get("Users") or []


def _attr_map(user: dict) -> dict[str, str]:
    return {a["Name"]: a["Value"] for a in user.get("Attributes") or []}


# Cognito federated usernames arrive as "{provider}_{subject}" with a lowercase
# provider prefix (e.g. "google_…"), but AdminLinkProviderForUser requires the
# exact IdP name configured on the pool ("Google").
_PROVIDER_NAME_BY_PREFIX = {
    "google": "Google",
    "facebook": "Facebook",
    "loginwithamazon": "LoginWithAmazon",
    "signinwithapple": "SignInWithApple",
}

_FEDERATED_PREFIXES = tuple(f"{p}_" for p in _PROVIDER_NAME_BY_PREFIX)


def _is_federated_username(username: str) -> bool:
    return username.lower().startswith(_FEDERATED_PREFIXES)


def _pick_destination(users: list[dict]) -> dict:
    """Prefer a native Cognito user over an already-federated Google_* profile."""
    native = [
        u
        for u in users
        if not _is_federated_username(str(u.get("Username", "")))
    ]
    confirmed = [u for u in native if u.get("UserStatus") in ("CONFIRMED", "EXTERNAL_PROVIDER")]
    if confirmed:
        return confirmed[0]
    if native:
        return native[0]
    return users[0]


def _parse_external_username(user_name: str) -> tuple[str, str]:
    # Cognito external usernames look like "google_<subject>" (prefix lowercased).
    provider, _, subject = user_name.partition("_")
    if not provider or not subject:
        raise ValueError(f"Unexpected federated username: {user_name}")
    canonical = _PROVIDER_NAME_BY_PREFIX.get(provider.lower())
    if canonical is None:
        raise ValueError(f"Unsupported federated provider prefix: {provider}")
    return canonical, subject


def handler(event, context):
    trigger = event.get("triggerSource", "")
    user_pool_id = event["userPoolId"]
    attrs = event.get("request", {}).get("userAttributes", {})
    email = (attrs.get("email") or "").strip()

    LOG.info("pre_signup trigger=%s userName=%s email=%s", trigger, event.get("userName"), email)

    if not email:
        if trigger == "PreSignUp_SignUp":
            raise Exception("EMAIL_REQUIRED")
        return event

    if trigger == "PreSignUp_SignUp":
        existing = _find_users_by_email(user_pool_id, email)
        if existing:
            LOG.info("reject signup: email already in use")
            raise Exception("EMAIL_EXISTS")
        _notify_new_user(email, trigger)
        return event

    if trigger == "PreSignUp_ExternalProvider":
        existing = _find_users_by_email(user_pool_id, email)
        if not existing:
            # First time this email appears via Google — allow Cognito to create the user.
            event.setdefault("response", {})
            event["response"]["autoConfirmUser"] = True
            event["response"]["autoVerifyEmail"] = True
            _notify_new_user(email, trigger)
            return event

        destination = _pick_destination(existing)
        dest_username = destination["Username"]
        # Skip if the matched user is already this same federated username.
        if dest_username == event.get("userName"):
            return event

        provider_name, provider_subject = _parse_external_username(event["userName"])
        LOG.info(
            "linking provider=%s subject=%s -> destination=%s",
            provider_name,
            provider_subject,
            dest_username,
        )

        cognito.admin_link_provider_for_user(
            UserPoolId=user_pool_id,
            DestinationUser={
                "ProviderName": "Cognito",
                "ProviderAttributeValue": dest_username,
            },
            SourceUser={
                "ProviderName": provider_name,
                "ProviderAttributeName": "Cognito_Subject",
                "ProviderAttributeValue": provider_subject,
            },
        )

        # Stop Cognito from creating a duplicate Google_* user. After this link,
        # the next Google SSO attempt signs in as the destination user (same sub).
        raise Exception("EXTERNAL_PROVIDER_LINKED")

    return event
