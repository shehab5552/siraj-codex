import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('branding',ROOT/'tool/generate_android_branding.py')
branding=importlib.util.module_from_spec(spec);spec.loader.exec_module(branding)
class BrandingTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='siraj-branding-test-');self.root=Path(self.temp.name)
        (self.root/'pubspec.yaml').write_text('name: siraj\n')
        self.source=self.root/'source.png';Image.new('RGBA',(1024,1024),(0,120,80,255)).save(self.source)
    def tearDown(self):self.temp.cleanup()
    def generate(self,source=None,sha=None):
        src=source or self.source
        return branding.generate(src,self.root,sha or hashlib.sha256(src.read_bytes()).hexdigest(),'reference-monogram')
    def test_actual_sizes_adaptive_safe_zone_and_classification(self):
        r=self.generate();self.assertFalse(r['official_logo_verified'])
        for d,s in branding.DENSITIES.items():
            with Image.open(self.root/f'android/app/src/main/res/mipmap-{d}/ic_launcher.png') as image:self.assertEqual(image.size,(round(48*s),round(48*s)))
        with Image.open(self.root/'android/app/src/main/res/drawable-nodpi/siraj_launcher_foreground.png') as image:
            self.assertEqual(image.getbbox(),(84,84,348,348))
    def test_bad_hash_does_not_replace_existing_resources(self):
        r=self.generate();before={p:(self.root/p).read_bytes() for p in r['generated']}
        with self.assertRaises(ValueError):self.generate(sha='0'*64)
        self.assertEqual(before,{p:(self.root/p).read_bytes() for p in r['generated']})
    def test_small_and_symlink_sources_rejected(self):
        small=self.root/'small.png';Image.new('RGBA',(48,48)).save(small)
        with self.assertRaises(ValueError):self.generate(small)
        link=self.root/'link.png';link.symlink_to(self.source)
        with self.assertRaises(ValueError):self.generate(link)
    def test_output_symlink_rejected_before_first_write(self):
        outside=self.root/'outside';outside.mkdir();(self.root/'android').symlink_to(outside,target_is_directory=True)
        with self.assertRaises(ValueError):self.generate()
        self.assertEqual(list(outside.iterdir()),[])
    def test_generation_is_repeatable(self):
        first=self.generate();second=self.generate();self.assertEqual(first,second)
if __name__=='__main__':unittest.main()
