import os
from pathlib import Path

block = 'b02'
audioDir = f'C:/Users/saosorio/Projects/WorkingMemory_CP/SternbergTask-PSB/output/fullSetup/cpeeg01/offmed_offstim/{block}/AudioFiles'

for filename in os.listdir(audioDir):
    new_name = filename
    new_name = new_name.replace('Block', 'b')
    
    # Lowercase everything
    new_name = new_name.lower()
    
    if new_name != filename:
        os.rename(Path(audioDir) / filename, Path(audioDir) /new_name)
        print(f'{filename} → {new_name}')