// EngineScript External Services interaction helpers
// Drag/drop, keyboard reordering, and notifications extracted from external-services.js

const DND_MOVE_TOKEN = 'moving';

// Standard CSSOM numeric value for KEYFRAMES_RULE, used when CSSRule.KEYFRAMES_RULE is unavailable (legacy browsers).
const LEGACY_KEYFRAMES_RULE_TYPE = 7;

/**
 * Attach interaction and accessibility methods to ExternalServicesManager.
 *
 * @param {Function} managerClass - ExternalServicesManager class constructor
 * @returns {void}
 */
export function attachExternalServicesInteractionMethods(managerClass) {
  Object.assign(managerClass.prototype, {
    /**
     * Enable drag-and-drop for service cards.
     * @param {HTMLElement} container - Container element holding service cards
     * @returns {void}
     */
    enableServiceDragDrop(container) {
      const serviceCards = container.querySelectorAll('.external-service-card');
      let draggedElement = null;

      const reorderInstructionsId = 'external-services-reorder-instructions';
      let reorderInstructions = container.querySelector(`#${reorderInstructionsId}`);
      if (!reorderInstructions) {
        reorderInstructions = document.createElement('p');
        reorderInstructions.id = reorderInstructionsId;
        reorderInstructions.className = 'sr-only';
        reorderInstructions.textContent = 'To reorder services, press Enter on a card to enter reorder mode, then use arrow keys to move it.';
        container.insertBefore(reorderInstructions, container.firstChild);
      }

      this.cachedCardOrder = null;

      serviceCards.forEach((card) => {
        card.draggable = true;

        // Add tabindex for keyboard accessibility
        card.setAttribute('tabindex', '0');
        card.setAttribute('role', 'listitem');
        const serviceName = card.dataset.serviceName || card.querySelector('h4')?.textContent || 'Service';
        card.setAttribute('aria-label', `${serviceName} (reorderable)`);
        card.setAttribute('aria-describedby', reorderInstructionsId);

        card.addEventListener('dragstart', (e) => {
          draggedElement = card;
          this.cachedCardOrder = Array.from(container.querySelectorAll('.external-service-card'));
          card.classList.add('dragging');
          if (e.dataTransfer) {
            e.dataTransfer.effectAllowed = 'move';
            // Use a minimal plain-text token instead of serializing HTML content.
            // Note: drop handling intentionally recalculates positions from the live DOM.
            e.dataTransfer.setData('text/plain', DND_MOVE_TOKEN);
          }
        });

        card.addEventListener('dragover', (e) => {
          if (e.dataTransfer) {
            e.dataTransfer.dropEffect = 'move';
          }
          e.preventDefault();

          const targetCard = e.target.closest('.external-service-card');
          if (targetCard && targetCard !== draggedElement) {
            targetCard.classList.add('drag-over');
          }
        });

        card.addEventListener('dragenter', (e) => {
          const targetCard = e.target.closest('.external-service-card');
          if (targetCard && targetCard !== draggedElement) {
            targetCard.classList.add('drag-over');
          }
        });

        card.addEventListener('dragleave', (e) => {
          const targetCard = e.target.closest('.external-service-card');
          if (targetCard) {
            targetCard.classList.remove('drag-over');
          }
        });

        card.addEventListener('drop', (e) => {
          e.preventDefault();

          const targetCard = e.target.closest('.external-service-card');
          if (targetCard && targetCard !== draggedElement) {
            targetCard.classList.remove('drag-over');

            if (!this.cachedCardOrder) {
              return;
            }
            const allCards = this.cachedCardOrder;
            const draggedIndex = allCards.indexOf(draggedElement);
            const targetIndex = allCards.indexOf(targetCard);

            if (draggedIndex < targetIndex) {
              targetCard.parentNode.insertBefore(draggedElement, targetCard.nextSibling);
            } else {
              targetCard.parentNode.insertBefore(draggedElement, targetCard);
            }

            this.cachedCardOrder = Array.from(container.querySelectorAll('.external-service-card'));

            // Save new order
            this.saveCardOrder();
          }
        });

        card.addEventListener('dragend', () => {
          card.classList.remove('dragging');
          this.cachedCardOrder = null;
          container.querySelectorAll('.external-service-card').forEach((serviceCard) => {
            serviceCard.classList.remove('drag-over');
          });
        });
      });

      // Enable keyboard navigation for accessibility
      this.enableKeyboardNavigation(container);
    },

    /**
     * Enable keyboard navigation for service card reordering.
     * @param {HTMLElement} container - Container element holding service cards
     * @returns {void}
     */
    enableKeyboardNavigation(container) {
      // Remove existing handler if present (prevents duplicate listeners on reload)
      if (this.keyboardHandler) {
        container.removeEventListener('keydown', this.keyboardHandler);
      }

      this.keyboardHandler = (e) => {
        const focusedCard = document.activeElement;

        // Only handle events on service cards
        if (!focusedCard || !focusedCard.classList.contains('external-service-card')) {
          return;
        }

        const allCards = Array.from(container.querySelectorAll('.external-service-card'));
        const currentIndex = allCards.indexOf(focusedCard);

        if (currentIndex === -1) return;

        switch (e.key) {
          case 'Enter':
          case ' ':
            // Toggle reorder mode on Enter or Space
            e.preventDefault();
            this.toggleReorderMode(focusedCard);
            break;

          case 'Escape':
            // Exit reorder mode
            if (this.reorderMode) {
              e.preventDefault();
              this.exitReorderMode();
            }
            break;

          case 'ArrowUp':
          case 'ArrowLeft':
            e.preventDefault();
            if (this.reorderMode && this.selectedCard === focusedCard) {
              // Move card up/left in reorder mode
              this.moveCardUp(focusedCard, allCards, currentIndex);
            } else {
              // Navigate to previous card
              this.focusPreviousCard(allCards, currentIndex);
            }
            break;

          case 'ArrowDown':
          case 'ArrowRight':
            e.preventDefault();
            if (this.reorderMode && this.selectedCard === focusedCard) {
              // Move card down/right in reorder mode
              this.moveCardDown(focusedCard, allCards, currentIndex);
            } else {
              // Navigate to next card
              this.focusNextCard(allCards, currentIndex);
            }
            break;

          case 'Home':
            // Move to first card
            e.preventDefault();
            if (allCards.length > 0) {
              allCards[0].focus();
            }
            break;

          case 'End':
            // Move to last card
            e.preventDefault();
            if (allCards.length > 0) {
              allCards[allCards.length - 1].focus();
            }
            break;
        }
      };

      container.addEventListener('keydown', this.keyboardHandler);
    },

    /**
     * Toggle reorder mode for a card.
     * @param {HTMLElement} card - Service card element to toggle reorder mode on
     * @param {string|null} serviceName - Optional service name for announcements
     * @returns {void}
     */
    toggleReorderMode(card, serviceName = null) {
      if (this.reorderMode && this.selectedCard === card) {
        // Exit reorder mode
        this.exitReorderMode();
        this.showNotification('Reorder mode exited. Order saved.', 'info');
      } else {
        // Enter reorder mode
        this.reorderMode = true;
        this.selectedCard = card;
        card.classList.add('reorder-active');
        card.setAttribute('aria-grabbed', 'true');

        const announcementName =
          serviceName ||
          card.getAttribute('data-service-name') ||
          card.querySelector('h4')?.textContent ||
          'service';

        // Announce to screen readers
        this.announceToScreenReader(`Reorder mode. Use arrow keys to move ${announcementName}. Press Enter or Escape to exit.`);
        this.showNotification('Reorder mode: Use arrow keys to move, Enter/Escape to exit', 'info');
      }
    },

    /**
     * Exit reorder mode.
     * @returns {void}
     */
    exitReorderMode() {
      if (this.selectedCard) {
        this.selectedCard.classList.remove('reorder-active');
        this.selectedCard.setAttribute('aria-grabbed', 'false');
      }
      this.reorderMode = false;
      this.selectedCard = null;
    },

    /**
     * Move card up (toward beginning of list).
     * @param {HTMLElement} card - Service card element to move
     * @param {HTMLElement[]} allCards - Array of all service card elements
     * @param {number} currentIndex - Current position index of the card
     * @returns {void}
     */
    moveCardUp(card, allCards, currentIndex) {
      if (currentIndex > 0) {
        const prevCard = allCards[currentIndex - 1];
        prevCard.parentNode.insertBefore(card, prevCard);
        card.focus();
        this.saveCardOrder();
        this.announceToScreenReader(`Moved to position ${currentIndex}`);
      } else {
        this.announceToScreenReader('Already at the beginning');
      }
    },

    /**
     * Move card down (toward end of list).
     * @param {HTMLElement} card - Service card element to move
     * @param {HTMLElement[]} allCards - Array of all service card elements
     * @param {number} currentIndex - Current position index of the card
     * @returns {void}
     */
    moveCardDown(card, allCards, currentIndex) {
      if (currentIndex < allCards.length - 1) {
        const nextCard = allCards[currentIndex + 1];
        nextCard.parentNode.insertBefore(card, nextCard.nextSibling);
        card.focus();
        this.saveCardOrder();
        this.announceToScreenReader(`Moved to position ${currentIndex + 2}`);
      } else {
        this.announceToScreenReader('Already at the end');
      }
    },

    /**
     * Focus previous card in list.
     * @param {HTMLElement[]} allCards - Array of all service card elements
     * @param {number} currentIndex - Current position index
     * @returns {void}
     */
    focusPreviousCard(allCards, currentIndex) {
      if (currentIndex > 0) {
        allCards[currentIndex - 1].focus();
      }
    },

    /**
     * Focus next card in list.
     * @param {HTMLElement[]} allCards - Array of all service card elements
     * @param {number} currentIndex - Current position index
     * @returns {void}
     */
    focusNextCard(allCards, currentIndex) {
      if (currentIndex < allCards.length - 1) {
        allCards[currentIndex + 1].focus();
      }
    },

    /**
     * Announce message to screen readers via live region.
     * @param {string} message - Message to announce
     * @returns {void}
     */
    announceToScreenReader(message) {
      if (!this.liveRegion) {
        this.liveRegion = document.createElement('div');
        this.liveRegion.id = 'es-live-region';
        this.liveRegion.setAttribute('aria-live', 'polite');
        this.liveRegion.setAttribute('aria-atomic', 'true');
        this.liveRegion.className = 'sr-only';
        document.body.appendChild(this.liveRegion);
      }

      // Clear and set message (triggers announcement)
      this.liveRegion.textContent = '';
      setTimeout(() => {
        this.liveRegion.textContent = message;
      }, this.liveRegionAnnouncementDelayMs);
    },

    /**
     * Save current card order to cookie.
     * @returns {void}
     */
    saveCardOrder() {
      const cards = document.querySelectorAll('.external-service-card');
      const orderArray = Array.from(cards)
        .filter((card) => card?.dataset?.serviceKey)
        .map((card) => card.dataset.serviceKey);
      this.saveServiceOrder(orderArray);
    },

    /**
     * Safely retrieve CSS rules from a single stylesheet.
     * @param {CSSStyleSheet} styleSheet
     * @returns {CSSRuleList|null}
     */
    getSheetRules(styleSheet) {
      try {
        return styleSheet.cssRules || styleSheet.rules;
      } catch (e) {
        // Ignore expected cross-origin access errors, but surface unexpected failures.
        if (e.name === 'SecurityError') {
          return null;
        }
        console.warn('Error accessing stylesheet rules:', e);
        return null;
      }
    },

    /**
     * Check whether a keyframes animation exists in currently loaded stylesheets.
     * @param {string} animationName - CSS keyframes name to look for
     * @returns {boolean}
     */
    hasAnimationKeyframes(animationName) {
      const styleSheets = Array.from(document.styleSheets || []);
      const keyframesType = typeof CSSRule !== 'undefined' ? CSSRule.KEYFRAMES_RULE : LEGACY_KEYFRAMES_RULE_TYPE;

      for (const styleSheet of styleSheets) {
        const rules = this.getSheetRules(styleSheet);
        if (!rules) continue;

        for (const rule of Array.from(rules)) {
          if (rule.type === keyframesType && rule.name === animationName) {
            return true;
          }
        }
      }

      return false;
    },

    /**
     * Convert milliseconds to seconds for CSS time values.
     * @param {number} durationMs
     * @returns {number}
     */
    millisecondsToSeconds(durationMs) {
      return durationMs / 1000;
    },

    /**
     * Schedule notification slide-out and removal.
     * @param {HTMLElement} notification - Notification element to remove
     * @returns {void}
     */
    scheduleNotificationRemoval(notification) {
      setTimeout(() => {
        if (this.hasAnimationKeyframes(this.notificationSlideOutAnimationName)) {
          notification.style.animation = `${this.notificationSlideOutAnimationName} ${this.millisecondsToSeconds(this.notificationAnimationDurationMs)}s ease`;
        }
        setTimeout(() => notification.remove(), this.notificationAnimationDurationMs);
      }, this.notificationDurationMs);
    },

    /**
     * Show notification to user.
     * @param {string} message - Notification message text
     * @param {string} [type='info'] - Notification type ('info', 'success', or 'error')
     * @returns {void}
     */
    showNotification(message, type = 'info') {
      const notification = document.createElement('div');
      notification.className = `es-notification notification-${type}`;
      notification.textContent = message;
      notification.setAttribute('role', 'status');
      notification.setAttribute('aria-live', 'polite');

      document.body.appendChild(notification);
      this.scheduleNotificationRemoval(notification);
    }
  });
}
