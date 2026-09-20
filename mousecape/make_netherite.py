#!/usr/bin/env python3
"""Build the Minecraft Netherite cape from the rw-designer Windows pack."""
import sys
from win2cape import convert

# Identifiers verified against a `mousecloak --dump` of this Mac's own cursors.
MAPPING = {
    '1 - Normal Select.cur':        ['com.apple.coregraphics.Arrow'],
    '2 - Help Select.cur':          ['com.apple.cursor.40'],                    # help (?)
    '3 - Working in Background.ani': ['com.apple.cursor.4'],                    # arrow + busy
    '4 - Busy .ani':                ['com.apple.coregraphics.Wait'],            # beachball
    '5 - Percision.cur':            ['com.apple.cursor.7',                      # crosshair
                                     'com.apple.cursor.8',                      # crosshair 2
                                     'com.apple.cursor.41'],                    # cell
    '6 - Text Select.cur':          ['com.apple.coregraphics.IBeam'],
    '8 - Vertical.cur':             ['com.apple.cursor.21', 'com.apple.cursor.22',
                                     'com.apple.cursor.23',                      # resize N/S/N-S
                                     'com.apple.cursor.31', 'com.apple.cursor.32',
                                     'com.apple.cursor.36'],                     # window N/S edges
    '9 - Horizontal.cur':           ['com.apple.cursor.17', 'com.apple.cursor.18',
                                     'com.apple.cursor.19',                      # resize W/E/W-E
                                     'com.apple.cursor.27', 'com.apple.cursor.28',
                                     'com.apple.cursor.38'],                     # window W/E edges
    '10 - Diagonal resize 1.cur':   ['com.apple.cursor.33', 'com.apple.cursor.34',
                                     'com.apple.cursor.37'],                     # NW-SE corners
    '11 - Diagonal resize 2.cur':   ['com.apple.cursor.29', 'com.apple.cursor.30',
                                     'com.apple.cursor.35'],                     # NE-SW corners
    '12 - Mover.cur':               ['com.apple.coregraphics.Move',
                                     'com.apple.cursor.39'],                     # 4-way move
    '15 - Link Select.ani':         ['com.apple.cursor.13'],                      # pointing hand
}

META = {
    'Author': 'jaqna (rw-designer.com/user/113017)',
    'CapeName': 'Minecraft Netherite',
    'CapeVersion': 1.0,
    'Cloud': False,
    'HiDPI': True,
    'Identifier': 'com.rwdesigner.jaqna.minecraft-netherite',
    'MinimumVersion': 2.0,
    'Version': 2.0,
}

if __name__ == '__main__':
    pack, out = sys.argv[1], sys.argv[2]
    cursors = convert(pack, MAPPING, out, META)
    print(f'\nWrote {out} with {len(cursors)} cursor slots.')
