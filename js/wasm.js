var memory;
var exports;

const getRandomSeed = () => Math.floor(Math.random() * 2147483647);
const getRandomString = () => Math.random().toString(36).substring(5, 15) + Math.random().toString(36).substring(5, 15);
const consoleLog = (value) => console.log('consoleLog', value);
const consoleLogS = (ptr, len) => { console.log(readCharStr(ptr, len)); };

function copyBytesToWASM(str) {
    var arr;
    if (typeof str === 'string')
        arr = new TextEncoder().encode(str);
    else
        arr = str;

    const len = arr.byteLength;
    if (len === 0)
        return {success: false};

    const ptr = exports._wasm_alloc(len);
    const view = new DataView(memory.buffer, ptr, len);
    //console.log("setting " + len + " bytes at address " + ptr);
    for (let i = 0; i < len; ++i) {
        view.setUint8(i, arr[i], true);
    }
    return {success: true, ptr, len};
}

function fetchImage(url, token) {
    var image = new Image();
    image.onload = function() {
        var canvas = document.createElement('canvas');
        const w = this.naturalWidth;
        const h = this.naturalHeight;
        canvas.width = w; // or 'width' if you want a special/scaled size
        canvas.height = h; // or 'height' if you want a special/scaled size
        var ctx = canvas.getContext('2d');
        ctx.drawImage(this, 0, 0);
        const imageData = ctx.getImageData(0, 0, w, h);
        sendOnFetch(imageData.width, imageData.height, imageData.data, token);
    };
    image.src = url;
}

function sendOnFetch(width, height, bytes, token) {
    var res = copyBytesToWASM(bytes);
    if (res.success) {
        setTimeout(function() { exports.onFetch(width, height, res.ptr, res.len, token); }, 0);
    } else {
        console.error("copyBytesToWASM failed");
    }
}

const fromJSON = (ptr, len) => JSON.parse(readCharStr(ptr, len));

const onEquationResultJSON = (ptr, len) => {
    var obj = fromJSON(ptr, len);
    console.log("onEquationResult", obj);
};

const fetchBytes = (ptr, len, token) => {
    var url = readCharStr(ptr, len);
    if (url.endsWith(".png")) {
        fetchImage(url, token);
    } else {
        throw "unimplemented";
        fetch(url)
            .then(response => response.arrayBuffer())
            .then(bytes => {
                console.log("fetched " + bytes + " from " + url);
                console.log("TODO: " + url);
                sendOnFetch(bytes);
            });
    }
}

const _textDecoder = new TextDecoder();
const readCharStr = (ptr, len) => {
    const bytes = new Uint8Array(memory.buffer, ptr, len);
    let s = "";
    for (let i = 0; i < len; ++i) {
        s += String.fromCharCode(bytes[i]);
    }
    return s;
};

const debugBreak = () => {
    debugger;
};

var wasm = {
    consoleLog,
    getRandomSeed,
    getRandomString,
    consoleLogS,
    readCharStr,
    debugBreak,
    fetchBytes,
    onEquationResultJSON
}
