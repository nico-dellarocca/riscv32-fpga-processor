import unittest
from bin_to_mem import convert


class TestBinToMem(unittest.TestCase):
    def test_little_endian_instruction(self):
        self.assertEqual(convert(bytes.fromhex("9300a000"), 8),
                         "00a00093\n00000000\n")

    def test_padding(self):
        self.assertEqual(convert(bytes([1, 2, 3]), 4), "00030201\n")

    def test_image_too_large(self):
        with self.assertRaises(ValueError):
            convert(bytes(12), 8)

    def test_bad_capacity(self):
        with self.assertRaises(ValueError):
            convert(bytes(1), 3)


if __name__ == "__main__":
    unittest.main()
