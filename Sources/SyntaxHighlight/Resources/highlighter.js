// Replaces highlight.js's HTML emitter with one that reports scope ranges, so
// nothing has to go through an HTML document to be coloured.
//
// The core calls `openNode`/`closeNode` as well as `startScope`/`endScope`.
// Without them it throws, hides the error in `result.errorRaised`, and returns
// the plain code — which looks exactly like an unsupported language.
class RangeEmitter {
    constructor(options) {
        this.options = options;
        this.ranges = [];
        this.stack = [];
        this.offset = 0;
    }

    addText(text) {
        if (!text) return;
        const scope = this.stack[this.stack.length - 1];
        // Lengths are UTF-16 code units, which is what NSRange counts.
        if (scope) this.ranges.push([this.offset, text.length, scope]);
        this.offset += text.length;
    }

    startScope(scope) { this.stack.push(scope); }
    endScope() { this.stack.pop(); }
    openNode(scope) { this.startScope(scope); }
    closeNode() { this.endScope(); }
    closeAllNodes() { while (this.stack.length) this.endScope(); }

    // An embedded language brings its own emitter; its ranges are ours, moved.
    __addSublanguage(emitter, name) {
        for (const [start, length, scope] of emitter.ranges) {
            this.ranges.push([this.offset + start, length, scope]);
        }
        this.offset += emitter.offset;
    }

    // What the core reads into `result.value`.
    toHTML() { return JSON.stringify(this.ranges); }

    finalize() {
        this.closeAllNodes();
        return true;
    }
}

hljs.configure({ __emitter: RangeEmitter });

// The one entry point Swift calls. Highlighting an unregistered language throws,
// so it is checked first; an error is reported rather than passed off as code
// that simply has no scopes.
function highlightRanges(code, language) {
    if (!hljs.getLanguage(language)) return '{"unsupported":true}';

    const result = hljs.highlight(code, { language: language, ignoreIllegals: true });

    if (result.errorRaised) {
        return JSON.stringify({ error: String(result.errorRaised) });
    }
    return '{"ranges":' + result.value + '}';
}
