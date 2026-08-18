from browser_qa.auth_detector import detect_auth_wall

NORMAL_PAGE = """\
uid=1 document "Dashboard"
  uid=2 navigation "Main"
    uid=3 link "Home"
  uid=4 main
    uid=5 heading "Welcome back" level=1
    uid=6 button "Create New" focusable
"""

LOGIN_PAGE = """\
uid=1 document "Login"
  uid=2 main
    uid=3 heading "Sign In" level=1
    uid=4 textbox "Email" focusable
    uid=5 textbox "Password" focusable
    uid=6 button "Log In" focusable
"""

CAPTCHA_PAGE = """\
uid=1 document "Verify"
  uid=2 main
    uid=3 heading "Security Check" level=1
    uid=4 img "captcha challenge"
    uid=5 textbox "Enter captcha" focusable
    uid=6 button "Verify" focusable
"""

RECAPTCHA_PAGE = """\
uid=1 document "Login"
  uid=2 main
    uid=3 textbox "Email" focusable
    uid=4 textbox "Password" focusable
    uid=5 group "reCAPTCHA"
      uid=6 checkbox "I'm not a robot" focusable
    uid=7 button "Sign In" focusable
"""

MFA_PAGE = """\
uid=1 document "Two-Factor Authentication"
  uid=2 main
    uid=3 heading "Enter verification code" level=1
    uid=4 textbox "OTP code" focusable
    uid=5 button "Verify" focusable
    uid=6 link "Resend code"
"""

MFA_AUTHENTICATOR_PAGE = """\
uid=1 document "MFA"
  uid=2 main
    uid=3 heading "Authenticator" level=1
    uid=4 textbox "Enter authenticator code" focusable
    uid=5 button "Submit" focusable
"""


class TestNormalPages:
    def test_dashboard_no_auth(self) -> None:
        result = detect_auth_wall(NORMAL_PAGE)
        assert result.needs_human is False

    def test_login_page_password_only_low_weight(self) -> None:
        result = detect_auth_wall(LOGIN_PAGE)
        assert result.needs_human is False


class TestCaptchaDetection:
    def test_captcha_in_img(self) -> None:
        result = detect_auth_wall(CAPTCHA_PAGE)
        assert result.needs_human is True
        assert result.reason == "captcha_detected"

    def test_recaptcha(self) -> None:
        result = detect_auth_wall(RECAPTCHA_PAGE)
        assert result.needs_human is True
        assert result.reason == "captcha_detected"


class TestMFADetection:
    def test_otp_input(self) -> None:
        result = detect_auth_wall(MFA_PAGE)
        assert result.needs_human is True
        assert result.reason == "mfa_detected"

    def test_authenticator(self) -> None:
        result = detect_auth_wall(MFA_AUTHENTICATOR_PAGE)
        assert result.needs_human is True
        assert result.reason == "mfa_detected"


class TestConsecutiveFailures:
    def test_identical_snapshots_with_fail_count(self) -> None:
        result = detect_auth_wall(LOGIN_PAGE, prev_snapshot=LOGIN_PAGE, fail_count=2)
        assert result.needs_human is True
        assert result.reason == "consecutive_failures"

    def test_identical_snapshots_below_threshold(self) -> None:
        result = detect_auth_wall(LOGIN_PAGE, prev_snapshot=LOGIN_PAGE, fail_count=1)
        assert result.needs_human is False

    def test_different_snapshots_reset(self) -> None:
        result = detect_auth_wall(NORMAL_PAGE, prev_snapshot=LOGIN_PAGE, fail_count=5)
        assert result.needs_human is False
