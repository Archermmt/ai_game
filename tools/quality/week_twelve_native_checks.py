"""Frozen hover and capacity probes; silent mode never counts as audio acceptance."""
import argparse
from hover_native_checks import main

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--silent-audio', action='store_true')
    args = parser.parse_args()
    main('week_12', ['--audio-driver', 'Dummy'] if args.silent_audio else None)
