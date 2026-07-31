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

import boto3

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

cognito = boto3.client("cognito-idp")


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


def _pick_destination(users: list[dict]) -> dict:
    """Prefer a native Cognito user over an already-federated Google_* profile."""
    native = [
        u
        for u in users
        if not str(u.get("Username", "")).startswith(("Google_", "Facebook_", "LoginWithAmazon_", "SignInWithApple_"))
    ]
    confirmed = [u for u in native if u.get("UserStatus") in ("CONFIRMED", "EXTERNAL_PROVIDER")]
    if confirmed:
        return confirmed[0]
    if native:
        return native[0]
    return users[0]


def _parse_external_username(user_name: str) -> tuple[str, str]:
    # Cognito external usernames look like "Google_<subject>".
    provider, _, subject = user_name.partition("_")
    if not provider or not subject:
        raise ValueError(f"Unexpected federated username: {user_name}")
    return provider, subject


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
        return event

    if trigger == "PreSignUp_ExternalProvider":
        existing = _find_users_by_email(user_pool_id, email)
        if not existing:
            # First time this email appears via Google — allow Cognito to create the user.
            event.setdefault("response", {})
            event["response"]["autoConfirmUser"] = True
            event["response"]["autoVerifyEmail"] = True
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
