// Translation modes
export const TranslationMode = {
  OFF: 'off',
  TRANSLATION_ONLY: 'translation-only', 
  ORIGINAL_ONLY: 'original-only',
  BILINGUAL: 'bilingual'
}

// Make TranslationMode globally available for debugging
if (typeof window !== 'undefined') {
  window.TranslationMode = TranslationMode
}

// Translation function that calls Flutter's translation service
const translate = async (text) => {
  try {
    // Call Flutter's translation handler
      const result = await window.flutter_inappwebview.callHandler('translateText', text)
      return result || `Translation failed: ${text}`
  } catch (error) {
    console.error('Translation failed:', error)
    return `Translation error: ${text}`
  }
}

export class Translator {
  #translationMode = TranslationMode.OFF
  observedElements = new Set()
  #translatedElements = new WeakMap()
  #observer = null
  #translationQueue = []
  #isTranslating = false
  #maxConcurrent = 3 // Maximum concurrent translations
  #requestDelay = 500 // Delay between requests in ms

  constructor() {
    this.#initializeObserver()
  }

  #initializeObserver() {
    // Reduced rootMargin to ~1.5 pages instead of ~4 pages
    this.#observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.#queueTranslation(entry.target)
          }
        })
        this.#processQueue()
      },
      {
        rootMargin: '800px', // ~1.5 pages ahead
        threshold: 0
      }
    )
  }

  // Queue translation requests
  #queueTranslation(element) {
    if (this.#translationMode === TranslationMode.OFF) return
    if (this.#translatedElements.has(element)) return

    const text = element.innerText?.trim()
    if (!text) return

    // Add to queue if not already queued
    if (!this.#translationQueue.find(item => item.element === element)) {
      this.#translationQueue.push({ element, text })
    }
  }

  // Process queue one at a time with delay
  async #processQueue() {
    if (this.#isTranslating) return
    if (this.#translationQueue.length === 0) return
    if (this.#translationMode === TranslationMode.OFF) return

    this.#isTranslating = true

    // Process up to maxConcurrent items at once
    const batch = this.#translationQueue.splice(0, this.#maxConcurrent)

    for (const item of batch) {
      if (this.#translationMode === TranslationMode.OFF) break

      try {
        const translatedText = await translate(item.text)

        this.#translatedElements.set(item.element, {
          originalText: item.text,
          translatedText: translatedText
        })

        this.#applyTranslation(item.element, translatedText)
      } catch (error) {
        console.warn('Translation failed:', error)
      }

      // Add delay between requests to avoid rate limiting
      if (this.#translationQueue.length > 0) {
        await new Promise(resolve => setTimeout(resolve, this.#requestDelay))
      }
    }

    this.#isTranslating = false

    // Process remaining queue if any
    if (this.#translationQueue.length > 0 && this.#translationMode !== TranslationMode.OFF) {
      setTimeout(() => this.#processQueue(), this.#requestDelay)
    }
  }

  async setTranslationMode(mode) {
    if (!Object.values(TranslationMode).includes(mode)) {
      console.warn(`Invalid translation mode: ${mode}`)
      return
    }
    
    const oldMode = this.#translationMode
    this.#translationMode = mode
    
    if (oldMode !== mode) {
      // console.log(`Translation mode changed from ${oldMode} to ${mode}`)
      
      if (mode === TranslationMode.OFF) {
        // Turn off translation
        this.#updateTranslationDisplay()
      } else if (oldMode === TranslationMode.OFF) {
        // Turn on translation - force translate visible elements and wait for completion
        await this.#forceTranslateVisibleElements()
      } else {
        // Just update display mode
        this.#updateTranslationDisplay()
      }
    }

    // Re-render annotations after translation mode change (and after translation completion)
    if (window.reader && window.reader.annotationsByValue) {
      const existingAnnotations = Array.from(window.reader.annotationsByValue.values())
      if (existingAnnotations.length > 0) {
        // console.log('Re-rendering annotations after translation mode change:', existingAnnotations.length)
        window.renderAnnotations(existingAnnotations)
      }
    }
  }

  getTranslationMode() {
    return this.#translationMode
  }

  observeDocument(doc) {
    // console.log('Observing document for translation, doc:', doc)
    if (!doc) {
      console.warn('No document provided to observeDocument')
      return
    }
        
    const textElements = this.#walkTextNodes(doc.body || doc.documentElement)
    // console.log(`Found ${textElements.length} text elements to observe`)
    
    textElements.forEach(element => {
      if (!this.observedElements.has(element)) {
        this.#observer.observe(element)
        this.observedElements.add(element)
        // console.log('Added element to observer:', element.tagName, element.textContent?.substring(0, 50))
      }
    })
    
    // console.log(`Total observed elements: ${this.observedElements.size}`)
  }

  clearTranslations() {
    // Remove all translation elements and restore original content
    this.observedElements.forEach(element => {
      const translationElements = element.querySelectorAll('.translated-text')
      translationElements.forEach(trans => trans.remove())
      
      // Restore original text if hidden
      this.#restoreOriginalText(element)
    })
    
    // Clear observer
    this.#observer.disconnect()
    this.observedElements.clear()
    this.#translatedElements = new WeakMap()
    
    // Reinitialize observer
    this.#initializeObserver()
  }

  #walkTextNodes(root, rejectTags = ['pre', 'code', 'math', 'style', 'script']) {
    const elements = []

    // Define preferred paragraph-level elements
    const preferredTags = ['p', 'div', 'blockquote', 'li', 'dd', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'section', 'article', 'aside']
    // Define inline elements to skip (translate at parent level)
    const inlineTags = ['span', 'em', 'strong', 'b', 'i', 'u', 'a', 'font', 'mark', 'small', 'sub', 'sup']

    const walk = (node, depth = 0) => {
      if (depth > 15) return

      const children = Array.from(node.children || [])
      for (const child of children) {
        if (rejectTags.includes(child.tagName.toLowerCase())) {
          continue
        }

        // Skip translation elements
        if (child.classList.contains('translated-text')) {
          continue
        }

        // Skip inline elements - they should be translated as part of their parent
        if (inlineTags.includes(child.tagName.toLowerCase())) {
          // Don't add inline elements, but still traverse their children
          // in case they contain nested elements
          if (child.children.length > 0) {
            walk(child, depth + 1)
          }
          continue
        }

        // Prioritize paragraph-level elements
        if (preferredTags.includes(child.tagName.toLowerCase())) {
          // Check if it has meaningful text content
          const textContent = child.textContent?.trim()
          if (textContent && textContent.length > 0) {
            // Check if children are mostly inline elements or text
            const hasBlockChildren = Array.from(child.children).some(c =>
              !inlineTags.includes(c.tagName.toLowerCase()) &&
              !rejectTags.includes(c.tagName.toLowerCase())
            )

            // If no block-level children, this is a good translation unit
            if (!hasBlockChildren) {
              elements.push(child)
              continue // Don't traverse deeper into this element
            }
          }
          // If it has block children, traverse deeper
          walk(child, depth + 1)
          continue
        }

        // For non-preferred, non-inline elements
        const hasDirectText = Array.from(child.childNodes).some(node => {
          if (node.nodeType === Node.TEXT_NODE && node.textContent?.trim()) {
            return true
          }
          return false
        })

        if (child.children.length === 0 && child.textContent?.trim()) {
          elements.push(child)
        } else if (hasDirectText) {
          // Check if it's a leaf-like element with mostly text
          const textLength = child.textContent?.trim().length || 0
          if (textLength > 10) {
            elements.push(child)
          } else {
            walk(child, depth + 1)
          }
        } else if (child.children.length > 0) {
          walk(child, depth + 1)
        }
      }
    }

    walk(root)
    return elements
  }

  async #translateElement(element) {
    if (this.#translationMode === TranslationMode.OFF) return
    if (this.#translatedElements.has(element)) return
    
    const text = element.innerText?.trim()
    if (!text) return
    
    try {
      const translatedText = await translate(text)
      
      // Mark as translated to prevent re-processing
      this.#translatedElements.set(element, {
        originalText: text,
        translatedText: translatedText
      })
      
      this.#applyTranslation(element, translatedText)
    } catch (error) {
      console.warn('Translation failed:', error)
    }
  }

  #applyTranslation(element, translatedText) {
    // Remove existing translation if any
    const existingTranslation = element.querySelector('.translated-text')
    if (existingTranslation) {
      existingTranslation.remove()
    }

    // Create translation wrapper
    const wrapper = document.createElement('div')
    wrapper.className = 'translated-text'
    wrapper.setAttribute('data-translation-mark', '1')

    // Handle paragraph structure - convert newlines to proper HTML structure
    // Split by double newlines for paragraphs, single newlines for line breaks
    const paragraphs = translatedText.split(/\n\n+/).filter(p => p.trim())

    if (paragraphs.length > 1) {
      // Multiple paragraphs: create separate paragraph elements
      paragraphs.forEach((paraText, index) => {
        if (index > 0) {
          wrapper.appendChild(document.createElement('br'))
        }
        const para = document.createElement('div')
        para.className = 'translated-paragraph'
        // Handle single newlines within paragraphs
        const lines = paraText.split(/\n/).filter(l => l.trim())
        lines.forEach((lineText, lineIndex) => {
          if (lineIndex > 0) {
            para.appendChild(document.createElement('br'))
          }
          const span = document.createElement('span')
          span.textContent = lineText.trim()
          para.appendChild(span)
        })
        wrapper.appendChild(para)
      })
    } else {
      // Single paragraph: handle single newlines as line breaks
      const lines = translatedText.split(/\n/).filter(l => l.trim())
      lines.forEach((lineText, index) => {
        if (index > 0) {
          wrapper.appendChild(document.createElement('br'))
        }
        const span = document.createElement('span')
        span.textContent = lineText.trim()
        wrapper.appendChild(span)
      })
    }

    // Apply based on current mode
    this.#updateElementDisplay(element, wrapper)

    // Insert as sibling after the element, not as child
    element.parentNode.insertBefore(wrapper, element.nextSibling)
  }

  #updateElementDisplay(element, translationWrapper) {
    const data = this.#translatedElements.get(element)
    if (!data) return
    
    switch (this.#translationMode) {
      case TranslationMode.TRANSLATION_ONLY:
        this.#hideOriginalText(element)
        translationWrapper.style.display = 'block'
        break
        
      case TranslationMode.ORIGINAL_ONLY:
        this.#restoreOriginalText(element)
        translationWrapper.style.display = 'none'
        break
        
      case TranslationMode.BILINGUAL:
        this.#restoreOriginalText(element)
        translationWrapper.style.display = 'block'
        break
        
      case TranslationMode.OFF:
      default:
        this.#restoreOriginalText(element)
        translationWrapper.style.display = 'none'
        break
    }
  }

  #hideOriginalText(element) {
    // Use CSS to hide original content instead of removing DOM nodes
    if (!element.hasAttribute('data-original-visibility')) {
      element.setAttribute('data-original-visibility', 'hidden')
      
      // Hide all child nodes except translation elements using CSS
      Array.from(element.childNodes).forEach(node => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          const el = node
          if (!el.classList || !el.classList.contains('translated-text')) {
            // Store and hide using CSS
            if (!el.hasAttribute('data-original-display')) {
              el.setAttribute('data-original-display', el.style.display || 'initial')
              el.style.display = 'none'
            }
          }
        } else if (node.nodeType === Node.TEXT_NODE) {
          // For text nodes, store content and make invisible
          if (!node.__originalContent) {
            node.__originalContent = node.textContent
            node.textContent = ''
          }
        }
      })
    }
    
    // Mark element as having hidden text
    element.classList.add('translation-source-hidden')
  }

  #restoreOriginalText(element) {
    // Restore visibility by reversing the hide operations
    if (element.hasAttribute('data-original-visibility')) {
      // Restore all child nodes
      Array.from(element.childNodes).forEach(node => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          const el = node
          if (!el.classList || !el.classList.contains('translated-text')) {
            // Restore original display
            if (el.hasAttribute('data-original-display')) {
              const originalDisplay = el.getAttribute('data-original-display')
              el.style.display = originalDisplay === 'initial' ? '' : originalDisplay
              el.removeAttribute('data-original-display')
            }
          }
        } else if (node.nodeType === Node.TEXT_NODE) {
          // Restore text content
          if (node.__originalContent !== undefined) {
            node.textContent = node.__originalContent
            delete node.__originalContent
          }
        }
      })
      
      element.removeAttribute('data-original-visibility')
    }
    
    element.classList.remove('translation-source-hidden')
  }

  async #forceTranslateVisibleElements() {
    // console.log('Force translating visible elements')

    // Find elements in viewport and queue them for translation
    this.observedElements.forEach(element => {
      const rect = element.getBoundingClientRect()
      const isVisible = rect.top < window.innerHeight && rect.bottom > 0

      if (isVisible && !this.#translatedElements.has(element)) {
        // Queue visible elements for sequential translation
        this.#queueTranslation(element)
      } else if (isVisible && this.#translatedElements.has(element)) {
        // Element already translated, just update display
        const translationWrapper = element.querySelector('.translated-text')
        if (translationWrapper) {
          this.#updateElementDisplay(element, translationWrapper)
        }
      }
    })

    // Process the queue and wait for completion
    if (this.#translationQueue.length > 0) {
      // Process all queued items sequentially
      await this.#processQueueAndWait()
    }
  }

  // Process queue completely and wait for all translations
  async #processQueueAndWait() {
    // Set flag to prevent concurrent processing
    this.#isTranslating = true

    try {
      while (this.#translationQueue.length > 0 && this.#translationMode !== TranslationMode.OFF) {
        // Process next batch
        const batch = this.#translationQueue.splice(0, this.#maxConcurrent)

        for (const item of batch) {
          if (this.#translationMode === TranslationMode.OFF) break

          try {
            const translatedText = await translate(item.text)

            this.#translatedElements.set(item.element, {
              originalText: item.text,
              translatedText: translatedText
            })

            this.#applyTranslation(item.element, translatedText)
          } catch (error) {
            console.warn('Translation failed:', error)
          }

          // Add delay between requests to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, this.#requestDelay))
        }
      }
    } finally {
      // Always release the flag
      this.#isTranslating = false

      // Trigger processing of any remaining items (e.g., from IntersectionObserver)
      if (this.#translationQueue.length > 0 && this.#translationMode !== TranslationMode.OFF) {
        setTimeout(() => this.#processQueue(), this.#requestDelay)
      }
    }
  }

  #updateTranslationDisplay() {
    // console.log('Updating translation display for mode:', this.#translationMode, 'Elements:', this.observedElements.size)
    this.observedElements.forEach(element => {
      const translationWrapper = element.querySelector('.translated-text')
      if (translationWrapper) {
        // console.log('Updating display for element with translation:', element)
        this.#updateElementDisplay(element, translationWrapper)
      } else {
        // console.log('No translation wrapper found for element:', element)
      }
    })
  }

  // Public method to translate visible elements (called on page/chapter change)
  async translateVisibleElements() {
    if (this.#translationMode === TranslationMode.OFF) return
    await this.#forceTranslateVisibleElements()
  }

  // Translate a selected paragraph and insert inline below original
  async translateSelectedParagraph(cfi) {
    console.log('translateSelectedParagraph called, cfi:', cfi)

    // Find the paragraph element from CFI
    const element = this.#findElementByCfi(cfi)
    console.log('Found element:', element)
    if (!element) {
      console.warn('Could not find element for CFI:', cfi)
      return false
    }

    // Find the paragraph-level parent element
    const paragraphElement = this.#findParagraphParent(element)
    console.log('Found paragraph element:', paragraphElement)
    if (!paragraphElement) {
      console.warn('Could not find paragraph parent')
      return false
    }

    // If already translated, just show the translation
    if (this.#translatedElements.has(paragraphElement)) {
      console.log('Element already translated')
      const wrapper = paragraphElement.querySelector('.translated-text')
      if (wrapper) {
        wrapper.style.display = 'block'
        return true
      }
    }

    // Get text and translate
    const text = paragraphElement.innerText?.trim()
    if (!text) return false

    try {
      const translatedText = await translate(text)
      this.#translatedElements.set(paragraphElement, {
        originalText: text,
        translatedText: translatedText
      })
      this.#applyTranslation(paragraphElement, translatedText)
      return true
    } catch (error) {
      console.warn('Translation failed:', error)
      return false
    }
  }

  // Find element from CFI - prioritize CFI resolution, selection as fallback
  #findElementByCfi(cfi) {
    try {
      // Primary: resolve CFI directly (authoritative identifier)
      if (window.reader && window.reader.view) {
        const view = window.reader.view
        const resolved = view.resolveCFI?.(cfi)
        if (resolved && resolved.anchor) {
          const contents = view.renderer?.getContents?.()
          if (contents && contents.length > 0) {
            const doc = contents[0].doc
            if (doc) {
              const range = resolved.anchor(doc)
              if (range && range.startContainer) {
                return range.startContainer.parentElement
              }
            }
          }
        }
      }

      // Fallback: use current selection (works when selection is still active)
      const selection = window.getSelection()
      if (selection && selection.rangeCount > 0) {
        const range = selection.getRangeAt(0)
        if (range && range.startContainer) {
          return range.startContainer.parentElement
        }
      }
    } catch (e) {
      console.warn('CFI parse error:', e)
    }
    return null
  }

  // Find paragraph-level parent element
  #findParagraphParent(element) {
    const paragraphTags = ['P', 'DIV', 'BLOCKQUOTE', 'LI', 'DD', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'SECTION', 'ARTICLE']
    const inlineTags = ['SPAN', 'EM', 'STRONG', 'B', 'I', 'U', 'A', 'FONT', 'MARK', 'SMALL', 'SUB', 'SUP', 'BR']

    let current = element
    while (current && current !== document.body) {
      if (paragraphTags.includes(current.tagName)) {
        // Check if it's a true paragraph (no block-level children)
        const hasBlockChildren = Array.from(current.children).some(c =>
          !inlineTags.includes(c.tagName) && !paragraphTags.includes(c.tagName)
        )
        if (!hasBlockChildren) {
          return current
        }
      }
      current = current.parentElement
    }
    // Fallback: return the original element if no paragraph parent found
    return element
  }

  destroy() {
    this.clearTranslations()
    this.#observer = null
  }
}