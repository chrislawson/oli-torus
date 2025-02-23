// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in 'webpack.config.js'.
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from 'phoenix'
//     import socket from './socket'
//
import { selectCookieConsent } from 'components/cookies/CookieConsent';
import { selectCookiePreferences } from 'components/cookies/CookiePreferences';
import { retrieveCookies } from 'components/cookies/utils';
import { CreateAccountPopup } from 'components/messages/CreateAccountPopup';
import { Hooks } from 'hooks';
import NProgress from 'nprogress';
import { Socket } from 'phoenix';
import 'phoenix_html';
import { LiveSocket } from 'phoenix_live_view';
import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { initActivityBridge, initPreviewActivityBridge } from './activity_bridge';
import { showModal } from './modal';
import { enableSubmitWhenTitleMatches } from './package_delete';
import { onReady } from './ready';

const csrfToken = (document as any)
  .querySelector('meta[name="csrf-token"]')
  .getAttribute('content');
const liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  metadata: {
    keydown: (e: any, _el: any) => {
      return {
        key: e.key,
        shiftKey: e.shiftKey,
      };
    },
  },
});

// Show progress bar on live navigation and form submits
window.addEventListener('phx:page-loading-start', (_info) => NProgress.start());
window.addEventListener('phx:page-loading-stop', (_info) => NProgress.done());

(window as any).initActivityBridge = initActivityBridge;
(window as any).initPreviewActivityBridge = initPreviewActivityBridge;

// Expose React/Redux APIs to server-side rendered templates
function mount(Component: any, element: HTMLElement, context: any = {}) {
  ReactDOM.render(React.createElement(Component, context), element);
}

// Global functions and objects:
(window as any).OLI = {
  initActivityBridge,
  initPreviewActivityBridge,
  showModal,
  enableSubmitWhenTitleMatches,
  selectCookieConsent,
  selectCookiePreferences,
  retrieveCookies,
  onReady,
  CreateAccountPopup: (node: any, props: any) => mount(CreateAccountPopup, node, props),
};

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
(window as any).liveSocket = liveSocket;

$(() => {
  ($('[data-toggle="popover"]') as any).popover();
  ($('[data-toggle="tooltip"]') as any).tooltip();
  ($('.ui.dropdown') as any).dropdown();
  ($('.ui.dropdown.item') as any).dropdown();

  $('[data-toggle="popover"]').on('focus', (e) => {
    ($('[data-toggle="popover"]:not(.popup__click)') as any).popover('hide');
    ($(e.target) as any).popover('show');
  });
  $('[data-toggle="popover"]').on('blur', (e) => {
    if (!$(e.target).hasClass('popup__click')) {
      ($(e.target) as any).popover('hide');
    }
  });

  $('body').on('mousedown', (e) => {
    const isPopover = (e: JQuery.UIEventBase<HTMLElement>) =>
      $(e.target).data('toggle') === 'popover';
    const isClickable = (e: JQuery.UIEventBase<HTMLElement>) =>
      $(e.target).hasClass('popup__click');
    const isPopupContent = (e: JQuery.UIEventBase<HTMLElement>) =>
      $(e.target).parents('.popup__content').length > 0;
    const isFocused = (e: JQuery.UIEventBase<HTMLElement>) =>
      document.activeElement && $(document.activeElement).is($(e.target));

    if (!isPopover(e) && !isClickable(e) && !isPopupContent(e)) {
      return ($('[data-toggle="popover"]') as any).popover('hide');
    }
    if (isPopover(e) && isClickable(e) && isFocused(e)) {
      return ($(e.target) as any).popover('toggle');
    }
  });

  (window as any).hljs.initHighlightingOnLoad();
});
