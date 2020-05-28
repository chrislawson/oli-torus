import React, { useReducer, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { MultipleChoiceModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Choices } from './sections/Choices';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
import { MCReducer, MCActions } from './reducer';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';

const store = configureStore();

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {
  const [state, dispatch] = useReducer(MCReducer, props.model);
  const { projectSlug } = props;

  useEffect(() => {
    props.onEdit(state);
  }, [state]);

  const sharedProps = {
    model: state,
    editMode: props.editMode,
    projectSlug,
  };

  return (
    <div className="p-4 pl-5">
      <Stem
        editMode={props.editMode}
        stem={state.stem}
        onEditStem={content => dispatch(MCActions.editStem(content))} />
      <Choices {...sharedProps}
        onAddChoice={() => dispatch(MCActions.addChoice())}
        onEditChoice={(id, content) => dispatch(MCActions.editChoice(id, content))}
        onRemoveChoice={id => dispatch(MCActions.removeChoice(id))} />
      <Feedback {...sharedProps}
        onEditResponse={(id, content) => dispatch(MCActions.editFeedback(id, content))} />
      <Hints
        hints={state.authoring.parts[0].hints}
        editMode={props.editMode}
        onAddHint={() => dispatch(MCActions.addHint())}
        onEditHint={(id, content) => dispatch(MCActions.editHint(id, content))}
        onRemoveHint={id => dispatch(MCActions.removeHint(id))} />
    </div>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <MultipleChoice {...props} />
        <ModalDisplay/>
      </Provider>,
      mountPoint,
    );
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
