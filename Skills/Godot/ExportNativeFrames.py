"""Export one skill to friendly phase/frame names. Standard library only; no image edits."""
from pathlib import Path
import argparse,json,shutil,hashlib
ROOT=Path(__file__).resolve().parent

def export(skill_id,destination):
    catalog=json.loads((ROOT/'SectVFX/catalog.json').read_text())
    entry=next((x for x in catalog if x['id']==skill_id),None)
    if entry is None:raise ValueError('Unknown skill; see SectVFX/catalog.json')
    spec=json.loads((ROOT/entry['file']).read_text())
    output=Path(destination).expanduser().resolve()/skill_id
    output.mkdir(parents=True,exist_ok=False) # Never overwrite buyer edits or the asset pack.
    sets={'default':spec['phases'],**spec.get('direction_phases',{})}
    total=0
    for direction,phases in sets.items():
        for name,phase in phases.items():
            folder=output/direction/name;folder.mkdir(parents=True)
            sheet=ROOT/phase['sheet'];shutil.copy2(sheet,folder/'sheet.png')
            data={key:phase[key] for key in ['canvas','anchor','logical_canvas','motion'] if key in phase}
            data['sheet']='sheet.png';data['frames']=[]
            for i,frame in enumerate(phase['frames']):
                src=ROOT/frame['png'];dst=folder/f'frame_{i:03}.png'
                assert hashlib.sha256(src.read_bytes()).hexdigest()==frame['sha256']
                shutil.copy2(src,dst)
                assert src.read_bytes()==dst.read_bytes()
                data['frames'].append({'file':dst.name,'duration':frame['duration'],'sha256':frame['sha256'],'source_rect':frame['rect']})
                total+=1
            (folder/'phase.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    shutil.copy2(ROOT/entry['file'],output/'SOURCE_SKILL.json')
    (output/'READ_ME.txt').write_text('Native PNG phase export, not a full flattened skill animation.\nphase.json paths are local. SOURCE_SKILL.json preserves the original library manifest for playback settings; its SectVFX paths still refer to the original library.\nKeep frame durations, anchors, logical_canvas scaling, procedural trajectories and shaders when porting. See the original README.\n')
    return output,total
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('skill_id');parser.add_argument('destination')
    args=parser.parse_args();folder,count=export(args.skill_id,args.destination)
    print(f'Exported {count} frame records without pixel changes: {folder}')
