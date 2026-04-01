from unittest.mock import patch
from browser_qa.url_validator import validate_url


class TestSchemeValidation:
    def test_http_allowed(self) -> None:
        result = validate_url("http://example.com")
        assert result.allowed is True

    def test_https_allowed(self) -> None:
        result = validate_url("https://example.com")
        assert result.allowed is True

    def test_file_blocked(self) -> None:
        result = validate_url("file:///etc/passwd")
        assert result.allowed is False
        assert "scheme" in result.reason.lower()

    def test_javascript_blocked(self) -> None:
        result = validate_url("javascript:alert(1)")
        assert result.allowed is False

    def test_data_blocked(self) -> None:
        result = validate_url("data:text/html,<h1>hi</h1>")
        assert result.allowed is False

    def test_ftp_blocked(self) -> None:
        result = validate_url("ftp://files.example.com")
        assert result.allowed is False


class TestLocalhostAllowed:
    def test_localhost(self) -> None:
        result = validate_url("http://localhost:3000")
        assert result.allowed is True

    def test_127_0_0_1(self) -> None:
        result = validate_url("http://127.0.0.1:8080")
        assert result.allowed is True

    def test_0_0_0_0(self) -> None:
        result = validate_url("http://0.0.0.0:5000")
        assert result.allowed is True


class TestMetadataBlocked:
    def test_aws_metadata(self) -> None:
        result = validate_url("http://169.254.169.254/latest/meta-data/")
        assert result.allowed is False
        assert "metadata" in result.reason.lower()

    def test_metadata_google_internal(self) -> None:
        with patch(
            "browser_qa.url_validator.socket.getaddrinfo",
            return_value=[(None, None, None, None, ("169.254.169.254", 80))],
        ):
            result = validate_url("http://metadata.google.internal/computeMetadata/v1/")
            assert result.allowed is False

    def test_metadata_azure_internal(self) -> None:
        with patch(
            "browser_qa.url_validator.socket.getaddrinfo",
            return_value=[(None, None, None, None, ("169.254.169.254", 80))],
        ):
            result = validate_url("http://metadata.azure.internal/metadata/instance")
            assert result.allowed is False


class TestDNSResolve:
    def test_resolves_to_metadata_ip(self) -> None:
        with patch(
            "browser_qa.url_validator.socket.getaddrinfo",
            return_value=[(None, None, None, None, ("169.254.169.254", 80))],
        ):
            result = validate_url("http://evil-redirect.example.com")
            assert result.allowed is False

    def test_normal_domain(self) -> None:
        with patch(
            "browser_qa.url_validator.socket.getaddrinfo",
            return_value=[(None, None, None, None, ("93.184.216.34", 80))],
        ):
            result = validate_url("http://example.com")
            assert result.allowed is True

    def test_dns_failure_blocks(self) -> None:
        with patch(
            "browser_qa.url_validator.socket.getaddrinfo",
            side_effect=OSError("DNS resolution failed"),
        ):
            result = validate_url("http://nonexistent.invalid")
            assert result.allowed is False
            assert "resolve" in result.reason.lower()


class TestMalformedUrls:
    def test_empty_string(self) -> None:
        result = validate_url("")
        assert result.allowed is False

    def test_no_scheme(self) -> None:
        result = validate_url("example.com")
        assert result.allowed is False

    def test_just_scheme(self) -> None:
        result = validate_url("http://")
        assert result.allowed is False
