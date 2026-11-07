"""Shared fixtures: the build, once per session."""

from __future__ import annotations

import pytest

from dunjunz_revised.build import build


@pytest.fixture(scope="session")
def disc_filepaths():
    try:
        return build()
    except FileNotFoundError as e:
        pytest.skip(str(e))
