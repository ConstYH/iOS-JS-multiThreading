// JSON5 库的精简版实现
var JSON5 = (function() {
    function syntaxError(message, line, column) {
        var error = new SyntaxError(message);
        error.line = line;
        error.column = column;
        return error;
    }

    function parse(source) {
        console.log('parse source:', source);
        var line = 1;
        var column = 1;
        var position = 0;
        var source = String(source);
        var length = source.length;

        function next() {
            position++;
            column++;
            return source[position - 1];
        }

        function peek() {
            return source[position];
        }

        function skipWhitespace() {
            while (position < length) {
                var char = peek();
                if (char === ' ' || char === '\t' || char === '\r') {
                    next();
                } else if (char === '\n') {
                    next();
                    line++;
                    column = 1;
                } else {
                    break;
                }
            }
        }

        function parseValue() {
            skipWhitespace();
            var char = peek();

            switch (char) {
                case '{': return parseObject();
                case '[': return parseArray();
                case '"':
                case "'": return parseString();
                case 't': return parseTrue();
                case 'f': return parseFalse();
                case 'n': return parseNull();
                default:
                    if (char === '-' || (char >= '0' && char <= '9')) {
                        return parseNumber();
                    }
                    throw syntaxError('Unexpected character: ' + char, line, column);
            }
        }

        function parseObject() {
            next(); // Skip {
            var object = {};
            
            skipWhitespace();
            while (position < length && peek() !== '}') {
                var key = parseString();
                skipWhitespace();
                
                if (next() !== ':') {
                    throw syntaxError('Expected : after key', line, column);
                }
                
                var value = parseValue();
                object[key] = value;
                
                skipWhitespace();
                if (peek() === ',') {
                    next();
                    skipWhitespace();
                }
            }
            
            if (next() !== '}') {
                throw syntaxError('Expected }', line, column);
            }
            
            return object;
        }

        function parseArray() {
            next(); // Skip [
            var array = [];
            
            skipWhitespace();
            while (position < length && peek() !== ']') {
                array.push(parseValue());
                skipWhitespace();
                if (peek() === ',') {
                    next();
                    skipWhitespace();
                }
            }
            
            if (next() !== ']') {
                throw syntaxError('Expected ]', line, column);
            }
            
            return array;
        }

        function parseString() {
            var quote = next();
            var string = '';
            
            while (position < length) {
                var char = next();
                if (char === quote) {
                    return string;
                } else if (char === '\\') {
                    char = next();
                    switch (char) {
                        case '"':
                        case "'":
                        case '\\': string += char; break;
                        case 'n': string += '\n'; break;
                        case 't': string += '\t'; break;
                        default: string += '\\' + char;
                    }
                } else {
                    string += char;
                }
            }
            
            throw syntaxError('Unterminated string', line, column);
        }

        function parseNumber() {
            var number = '';
            if (peek() === '-') {
                number += next();
            }
            
            while (position < length && peek() >= '0' && peek() <= '9') {
                number += next();
            }
            
            if (peek() === '.') {
                number += next();
                while (position < length && peek() >= '0' && peek() <= '9') {
                    number += next();
                }
            }
            
            return parseFloat(number);
        }

        function parseTrue() {
            var value = '';
            for (var i = 0; i < 4; i++) {
                value += next();
            }
            if (value !== 'true') {
                throw syntaxError('Expected true', line, column);
            }
            return true;
        }

        function parseFalse() {
            var value = '';
            for (var i = 0; i < 5; i++) {
                value += next();
            }
            if (value !== 'false') {
                throw syntaxError('Expected false', line, column);
            }
            return false;
        }

        function parseNull() {
            var value = '';
            for (var i = 0; i < 4; i++) {
                value += next();
            }
            if (value !== 'null') {
                throw syntaxError('Expected null', line, column);
            }
            return null;
        }

        return parseValue();
    }

    return {
        parse: parse,
        stringify: JSON.stringify  // 使用原生 stringify
    };
})(); 