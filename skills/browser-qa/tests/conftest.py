import pytest

SAMPLE_SNAPSHOT = """\
uid=1 document "My App"
  uid=2 navigation "Main Nav"
    uid=3 link "Home"
    uid=4 link "About"
  uid=5 main
    uid=6 heading "Welcome" level=1
    uid=7 paragraph
    uid=8 group
      uid=9 textbox "Email" focusable
      uid=10 textbox "Password" focusable
      uid=11 button "Sign In" focusable
    uid=12 separator
    uid=13 group
"""

SAMPLE_SNAPSHOT_AFTER_LOGIN = """\
uid=1 document "My App"
  uid=2 navigation "Main Nav"
    uid=3 link "Home"
    uid=4 link "About"
    uid=20 link "Profile"
  uid=5 main
    uid=21 heading "Dashboard" level=1
    uid=22 button "Create New" focusable
    uid=23 table "Recent Items"
"""


@pytest.fixture
def sample_snapshot() -> str:
    return SAMPLE_SNAPSHOT


@pytest.fixture
def sample_snapshot_after_login() -> str:
    return SAMPLE_SNAPSHOT_AFTER_LOGIN
