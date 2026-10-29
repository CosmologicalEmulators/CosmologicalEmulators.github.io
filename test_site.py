"""Validate the actual generated aggregate; no third-party Python dependencies."""

import json
import re
import subprocess
import tomllib
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
CONFIG = tomllib.loads((ROOT / "packages.toml").read_text())


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.ids = set()
        self.links = []
        self.redirect = None
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag in ("a", "link", "script", "img"):
            value = attrs.get("href") or attrs.get("src")
            if value:
                self.links.append(value)
        if tag == "meta" and attrs.get("http-equiv", "").lower() == "refresh":
            match = re.search(r"url\s*=\s*(.+)", attrs.get("content", ""), re.I)
            if match:
                self.redirect = match[1]
                self.links.append(self.redirect)


def local_target(page, link):
    url = urlsplit(link)
    if url.scheme or url.netloc:
        return None
    path = unquote(url.path)
    if path.startswith("/"):
        target = BUILD / path.lstrip("/")
    else:
        target = page.parent / path if path else page
    target = target.resolve()
    if target.is_dir():
        target /= "index.html"
    return target, unquote(url.fragment)


class AggregateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pages = {p.resolve(): Page(p) for p in BUILD.rglob("*.html")}
        cls.index = json.loads((BUILD / "index.json").read_text())

    def test_all_configured_versions_present(self):
        for package in CONFIG["packages"]:
            for version in package["versions"]:
                with self.subTest(package=package["name"], version=version):
                    self.assertTrue((BUILD / package["path"] / version / "index.html").is_file())

    def test_navigation_and_search_on_every_content_page(self):
        self.assertGreater(len(self.pages), 10)
        for path, page in self.pages.items():
            if page.redirect:
                continue
            with self.subTest(page=str(path.relative_to(BUILD))):
                self.assertIn("multi-page-nav", page.ids)
                self.assertIn("search-input", page.ids)
                for package in CONFIG["packages"]:
                    expected = (BUILD / package["path"] / "index.html").resolve()
                    self.assertTrue(any(
                        target and target[0] == expected
                        for target in (local_target(path, link) for link in page.links)
                    ), package["name"])

    def test_internal_links_assets_and_fragments(self):
        failures = []
        for path, page in self.pages.items():
            for link in page.links:
                target = local_target(path, link)
                if target is None:
                    continue
                dest, anchor = target
                if not dest.is_relative_to(BUILD) or not dest.exists():
                    failures.append((str(path.relative_to(BUILD)), link, "missing file"))
                elif anchor and dest in self.pages and anchor not in self.pages[dest].ids:
                    failures.append((str(path.relative_to(BUILD)), link, "missing anchor"))
        self.assertEqual(failures, [])

    def test_search_covers_every_package_and_links_resolve(self):
        self.assertTrue(self.index)
        for package in CONFIG["packages"]:
            version = "stable" if "stable" in package["versions"] else "dev"
            prefix = f'/{package["path"]}/{version}/'
            entries = [e for e in self.index if e["ref"].startswith(prefix)]
            self.assertTrue(entries, package["name"])
            self.assertTrue(any(e["content"].strip() for e in entries), package["name"])
            for entry in entries:
                dest, anchor = local_target(BUILD / "index.html", entry["ref"])
                self.assertIn(dest, self.pages, entry["ref"])
                self.assertIn(anchor, self.pages[dest].ids, entry["ref"])
        self.assertTrue(any(e["ref"].startswith("/home/dev/") for e in self.index))

    def test_version_selectors_and_provenance(self):
        provenance = tomllib.loads((BUILD / "upstreams.toml").read_text())
        for package in CONFIG["packages"]:
            root = BUILD / package["path"]
            versions = (root / "versions.js").read_text()
            for version in package["versions"]:
                self.assertIn(f'"{version}"', versions)
            self.assertRegex(provenance[package["repo"]]["commit"], r"^[0-9a-f]{40}$")
            self.assertEqual(provenance[package["repo"]]["versions"], package["versions"])
            self.assertIn("See All Versions", (root / package["versions"][0] / "index.html").read_text())
        self.assertFalse(any(p.is_symlink() for p in BUILD.rglob("*")), "Pages artifacts cannot contain symlinks")
        self.assertFalse(any(p.name == ".git" for p in BUILD.rglob("*")))

    def test_neutrino_guide_is_searchable(self):
        self.assertTrue(any(e["ref"].startswith("/ace/dev/neutrinos/")
                            for e in self.index))

    def test_public_names_and_jax_versions(self):
        package = next(p for p in CONFIG["packages"]
                       if p["repo"] == "AbstractCosmologicalEmulators.jl")
        self.assertEqual(package["name"], "AbstractCosmologicalEmulators.jl")
        external = {p["name"]: p["url"] for p in CONFIG["external"]}
        home = (BUILD / "home/dev/index.html").read_text()
        for version in ("stable", "dev"):
            url = f"https://cosmologicalemulators.github.io/jaxace/{version}/"
            self.assertEqual(external[f"jaxace ({version})"], url)
            self.assertIn(url, home)
        self.assertNotIn("ACE.jl", home)

    def test_real_search_engine(self):
        subprocess.run(["node", str(ROOT / "test_search.cjs")], check=True, cwd=ROOT)


if __name__ == "__main__":
    unittest.main(verbosity=2)
