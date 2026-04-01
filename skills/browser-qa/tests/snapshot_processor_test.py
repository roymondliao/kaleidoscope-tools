from browser_qa.snapshot_processor import filter_snapshot


class TestFilterInteractive:
    def test_keeps_interactive_elements(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=True, compact=False)
        assert "uid=3 link" in result
        assert "uid=4 link" in result
        assert "uid=9 textbox" in result
        assert "uid=10 textbox" in result
        assert "uid=11 button" in result

    def test_removes_non_interactive_elements(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=True, compact=False)
        assert "uid=6 heading" not in result
        assert "uid=7 paragraph" not in result
        assert "uid=12 separator" not in result

    def test_preserves_parent_structure(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=True, compact=False)
        assert "uid=2 navigation" in result
        assert "uid=1 document" in result

    def test_preserves_indentation(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=True, compact=False)
        lines = result.strip().split("\n")
        home_line = [line for line in lines if "uid=3 link" in line][0]
        nav_line = [line for line in lines if "uid=2 navigation" in line][0]
        assert len(home_line) - len(home_line.lstrip()) > len(nav_line) - len(
            nav_line.lstrip()
        )


class TestFilterCompact:
    def test_removes_empty_structural_nodes(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=False, compact=True)
        assert "uid=13 group" not in result

    def test_keeps_nodes_with_children(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=False, compact=True)
        assert "uid=8 group" in result

    def test_removes_empty_paragraph(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=False, compact=True)
        assert "uid=7 paragraph" not in result


class TestFilterCombined:
    def test_interactive_and_compact(self, sample_snapshot: str) -> None:
        result = filter_snapshot(sample_snapshot, interactive=True, compact=True)
        assert "uid=9 textbox" in result
        assert "uid=11 button" in result
        assert "uid=6 heading" not in result
        assert "uid=13 group" not in result
        assert "uid=12 separator" not in result
