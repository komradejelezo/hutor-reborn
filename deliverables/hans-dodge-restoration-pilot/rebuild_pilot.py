#!/usr/bin/env python3
"""Composite frozen, curated image-editor pixels; never paint/inpaint by code.

The artwork pass was performed with image editing, not this script. Only this
pilot's restored/ directory is written; every other pixel comes from baseline.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
D=Path(__file__).resolve().parent;R=D.parents[1]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    recipe=json.loads((D/'CURATION.json').read_text())
    # Preflight every source before writing any result.
    for row in recipe['frames']:
        assert digest(R/row['source'])==row['source_sha256'],'Original changed; do not overwrite pilot'
        assert (D/'before'/f'dodge_{row["frame"]:02d}.png').read_bytes()==(R/row['source']).read_bytes()
        assert digest(D/'patches'/f'dodge_{row["frame"]:02d}.png')==row['patch_sha256'],'Curated patch changed; review it first'
        existing=D/'restored'/f'dodge_{row["frame"]:02d}.png'
        if existing.exists():assert digest(existing)==row['restored_sha256'],'Preserve manually edited pilot; do not overwrite'
    for row in recipe['frames']:
        name=f'dodge_{row["frame"]:02d}.png'
        baseline=np.array(Image.open(R/row['source']).convert('RGBA'))
        patch=np.array(Image.open(D/'patches'/name).convert('RGBA'))
        assert baseline.shape==patch.shape==(358,357,4)
        mask=patch[:,:,3]>0;assert np.all(patch[mask,3]==255)
        assert mask.sum()==row['edited_pixels']
        result=baseline.copy();result[mask]=patch[mask]
        assert np.all(result[:,:,3]>=baseline[:,:,3]),'No alpha loss'
        assert np.all(result[mask,:3].max(1)>8),'Never substitute flat opaque black'
        Image.fromarray(result).save(D/'restored'/name)
        assert digest(D/'restored'/name)==row['restored_sha256']
    print('PASS: three frozen pilot PNGs rebuilt; game files untouched')
if __name__=='__main__':main()
