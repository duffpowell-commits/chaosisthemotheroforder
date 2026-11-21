#!/usr/bin/env python3
"""Proves tools/art_qa.py catches obvious defects. Run: python tools/test_art_qa.py
Set ART_QA_REQUIRE_OCR=1 (CI) to fail instead of skip when Tesseract is missing."""
import json, os, shutil, sys, tempfile, unittest
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_qa  # noqa: E402

ROOT = art_qa.ROOT
FONT = os.path.join(ROOT, "assets", "fonts", "anton", "Anton-Regular.ttf")
REQUIRE_OCR = os.environ.get("ART_QA_REQUIRE_OCR") == "1"


def sprite(path, jacket=(92, 84, 60), bg=None, size=(300, 600)):
    """A crude A-pose figure; transparent background unless bg is given."""
    im = Image.new("RGBA", size, bg + (255,) if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w, h = size
    d.ellipse((w * .4, h * .05, w * .6, h * .17), fill=(170, 130, 100, 255))
    d.rectangle((w * .33, h * .18, w * .67, h * .55), fill=jacket + (255,))
    d.line((w * .33, h * .2, w * .12, h * .5), fill=jacket + (255,), width=18)
    d.line((w * .67, h * .2, w * .88, h * .5), fill=jacket + (255,), width=18)
    d.rectangle((w * .36, h * .55, w * .48, h * .93), fill=(70, 60, 45, 255))
    d.rectangle((w * .52, h * .55, w * .64, h * .93), fill=(70, 60, 45, 255))
    im.save(path)


class ArtQATest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="artqa_")
        self.cfg = art_qa.load_config(art_qa.DEFAULT_CONFIG)
        self.cfg["exceptions"] = {}
        self.cfg["groups"] = [
            {"name": "test civilian sprite", "globs": ["*qa_civ_*.png"], "sprite": True, "edge_alpha_max": 16,
             "size": {"h": 600}, "mode": ["RGBA"], "palette": {"red_max": 0.05, "maroon_max": 0.25, "blue_max": 0.1}},
            {"name": "test scene", "globs": ["*qa_scene_*.png"], "size": {"w": 1280, "h": 720},
             "palette": {"red_max": 2.0}},
        ]

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def p(self, name):
        return os.path.join(self.tmp, name)

    def check(self, *names, ocr=False):
        files = [art_qa.rel(self.p(n)) for n in names]
        failures, _ = art_qa.run(self.cfg, files, use_ocr=ocr, jobs=2)
        return {os.path.basename(k): v for k, v in failures.items()}

    def test_clean_sprite_passes(self):
        sprite(self.p("qa_civ_ok.png"))
        self.assertEqual(self.check("qa_civ_ok.png"), {})

    def test_off_palette_sprite_fails(self):
        sprite(self.p("qa_civ_red.png"), jacket=(190, 25, 20))
        sprite(self.p("qa_civ_blue.png"), jacket=(30, 70, 180))
        f = self.check("qa_civ_red.png", "qa_civ_blue.png")
        self.assertTrue(any(e.startswith("red ") for e in f["qa_civ_red.png"]), f)
        self.assertTrue(any(e.startswith("blue ") for e in f["qa_civ_blue.png"]), f)

    def test_off_palette_scene_fails(self):
        im = Image.new("RGB", (1280, 720), (90, 85, 70))
        ImageDraw.Draw(im).rectangle((100, 100, 700, 600), fill=(200, 20, 20))
        im.save(self.p("qa_scene_red.png"))
        f = self.check("qa_scene_red.png")
        self.assertTrue(any(e.startswith("red ") for e in f["qa_scene_red.png"]), f)

    def test_baked_background_and_edge_fail(self):
        sprite(self.p("qa_civ_grey.png"), bg=(200, 200, 200))
        f = self.check("qa_civ_grey.png")
        self.assertTrue(any("baked background" in e for e in f["qa_civ_grey.png"]), f)
        self.assertTrue(any("frame edge" in e for e in f["qa_civ_grey.png"]), f)

    def test_wrong_size_fails(self):
        Image.new("RGB", (1024, 576), (90, 85, 70)).save(self.p("qa_scene_small.png"))
        f = self.check("qa_scene_small.png")
        self.assertTrue(any("width" in e for e in f["qa_scene_small.png"]), f)

    def test_synthetic_text_is_caught(self):
        if not art_qa.ocr_available():
            if REQUIRE_OCR:
                self.fail("Tesseract not available but ART_QA_REQUIRE_OCR=1")
            self.skipTest("Tesseract not available")
        im = Image.new("RGB", (1280, 720), (233, 224, 204))
        d = ImageDraw.Draw(im)
        d.text((120, 260), "CHECKPOINT AHEAD", font=ImageFont.truetype(FONT, 110), fill=(27, 23, 20))
        im.save(self.p("qa_scene_text.png"))
        Image.new("RGB", (1280, 720), (233, 224, 204)).save(self.p("qa_scene_blank.png"))
        f = self.check("qa_scene_text.png", "qa_scene_blank.png", ocr=True)
        # OCR engines may misread a letter (e.g. CHEGKPOINT); any confirmed word counts.
        self.assertTrue(any("readable text" in e for e in f.get("qa_scene_text.png", [])), f)
        self.assertNotIn("qa_scene_blank.png", f)

    def test_allowlisted_token_passes(self):
        if not art_qa.ocr_available():
            self.skipTest("Tesseract not available")
        im = Image.new("RGB", (1280, 720), (233, 224, 204))
        ImageDraw.Draw(im).text((400, 260), "0417", font=ImageFont.truetype(FONT, 140), fill=(27, 23, 20))
        im.save(self.p("qa_scene_patch.png"))
        f = self.check("qa_scene_patch.png", ocr=True)
        self.assertNotIn("qa_scene_patch.png", f)


if __name__ == "__main__":
    unittest.main(verbosity=2)
