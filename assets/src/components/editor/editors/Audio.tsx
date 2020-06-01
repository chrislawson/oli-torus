import React from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { LabelledTextEditor } from 'components/TextEditor';

import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectAudio(projectSlug: string,
  model: ContentModel.Audio): Promise<ContentModel.Audio> {

  return new Promise((resolve, reject) => {

    const selected = { img: null };

    const mediaLibrary =
      <ModalSelection title="Select audio"
        onInsert={() => { dismiss(); resolve(selected.img as any); }}
        onCancel={() => dismiss()}>
        <MediaManager model={model}
          projectSlug={projectSlug}
          onEdit={() => { }}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={[model.src]}
          onSelectionChange={(images: MediaItem[]) => {
            const first : ContentModel.Audio = { type: 'audio', src: images[0].url,
              children: [{ text: '' }], id: guid() };
            (selected as any).img = first;
          }} />
      </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor: ReactEditor) => {
    const audio = ContentModel.create<ContentModel.Audio>(
      { type: 'audio', src: '', children: [{ text: '' }], id: guid() });
    selectAudio(context.projectSlug, audio)
    .then((img) => {
      Transforms.insertNodes(editor, img);
    });
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-music',
  description: 'Audio Clip',
  command,
};

export interface AudioProps extends EditorProps<ContentModel.Audio> {
}

export const AudioEditor = (props: AudioProps) => {

  const selected = useSelected();
  const focused = useFocused();

  const { attributes, children, editor } = props;
  const { model } = props;

  const editMode = getEditMode(editor);

  const centered = {
    display: 'flex',
    justifyContent: 'center',
    width: '100%',
  } as any;

  const playerStyle = {
    display: 'block',
    marginLeft: 'auto',
    marginRight: 'auto',
    border: (selected && focused) ? 'solid 3px darkblue' : 'solid 3px white',
  } as any;

  const onEditCaption = (caption: string) => updateModel(editor, model, { caption });
  const onEditAlt = (alt: string) => updateModel(editor, model, { alt });

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  const { src } = model;

  return (
    <div {...attributes}>

      <div contentEditable={false} style={{ userSelect: 'none' }}>

        <div style={centered}>
          <audio style={playerStyle} src={src} controls />
        </div>

        <div style={{ marginLeft: '30px' }}>
          <LabelledTextEditor
            label="Caption"
            model={model.caption || ''}
            onEdit={onEditCaption}
            showAffordances={selected && focused}
            editMode={editMode} />
        </div>
        <div style={{ marginLeft: '30px' }}>
          <LabelledTextEditor
            label="Alt"
            model={model.alt || ''}
            onEdit={onEditAlt}
            showAffordances={selected && focused}
            editMode={editMode} />
        </div>
      </div>

      {children}
    </div>
  );
};
