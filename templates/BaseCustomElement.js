/**
 * Base Custom Element Class
 *
 * Abstract base for all block custom elements in this theme.
 * Provides standardized registration with DOM-ready handling.
 *
 * Usage:
 *   import BaseCustomElement from '../core/BaseCustomElement.js';
 *
 *   export default class BlockHeroSection extends BaseCustomElement {
 *     static tagName = 'block-hero-section';
 *     init() {
 *       // Element behavior. Runs after DOMContentLoaded and after
 *       // the element is connected to the DOM.
 *     }
 *   }
 *
 *   BaseCustomElement.register(BlockHeroSection);
 */
export default class BaseCustomElement extends HTMLElement {
  static tagName = null;

  /**
   * Register a custom element class. Safe to call multiple times.
   *
   * @param {typeof BaseCustomElement} CustomElementClass
   */
  static register(CustomElementClass) {
    if (!CustomElementClass.tagName) {
      throw new Error(
        `${CustomElementClass.name} must define a static tagName property.`
      );
    }

    const tagName = CustomElementClass.tagName;

    if (customElements.get(tagName)) {
      return;
    }

    const define = () => {
      if (!customElements.get(tagName)) {
        customElements.define(tagName, CustomElementClass);
      }
    };

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', define, { once: true });
    } else {
      define();
    }
  }

  /**
   * Called by the browser when the element enters the DOM.
   * Defers init() until DOMContentLoaded to guarantee children are present.
   */
  connectedCallback() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.init(), {
        once: true,
      });
    } else {
      this.init();
    }
  }

  /**
   * Override in subclass. Empty is valid for static blocks.
   */
  init() {
    //
  }
}
