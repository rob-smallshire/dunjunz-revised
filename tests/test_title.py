"""The title's star animation draws the same frames as the 1987 release.

The star frame pointers were literal bytes for the frames' original address,
&2A00. Code added to the title moved the frames, and each star was drawn from
the bytes before its frame: a band of code above a misplaced star. The
pointers are now computed from star_frame_data; this checks they still point
at the original frames.
"""

from __future__ import annotations

from dunjunz_revised.build import ORIGINAL_BUILD_DIRPATH, REVISED_BUILD_DIRPATH, read_labels

TITLE_LOAD_ADDRESS = 0x26C0
FRAMES = 7
FRAME_BYTES = 7 * 28


def star_frames(build_dirpath):
    labels = read_labels(build_dirpath, "title")
    image = (build_dirpath / "Dunjunz").read_bytes()

    def byte(address):
        return image[address - TITLE_LOAD_ADDRESS]

    frames = []
    for frame in range(FRAMES):
        address = byte(labels["star_frames_lo"] + frame) | byte(labels["star_frames_hi"] + frame) << 8
        offset = address - TITLE_LOAD_ADDRESS
        frames.append(image[offset:offset + FRAME_BYTES])
    return frames


def test_star_frames_match_the_original(disc_filepaths):
    original = star_frames(ORIGINAL_BUILD_DIRPATH)
    assert all(len(frame) == FRAME_BYTES for frame in original)
    assert star_frames(REVISED_BUILD_DIRPATH) == original
