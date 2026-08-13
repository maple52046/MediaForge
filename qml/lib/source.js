.pragma library

function localPath(url) {
    const value = String(url);
    if (value.startsWith("file://localhost/"))
        return decodeURIComponent(value.slice("file://localhost".length));
    if (value.startsWith("file:///"))
        return decodeURIComponent(value.slice("file://".length));
    return "";
}

function firstDroppedPath(urls) {
    if (urls === null || urls === undefined || urls.length === 0)
        return "";
    return localPath(urls[0]);
}
