// const { sign, format } = require("js-conflux-sdk");
import { sign, format } from "js-conflux-sdk";

export function loadPrivateKey() {
    if (process.env.PRIVATE_KEY) {
        return process.env.PRIVATE_KEY;
    } else {
        const keystore = require(process.env.KEYSTORE as string);
        const privateKeyBuf = sign.decrypt(keystore, process.env.KEYSTORE_PWD as string);
        return format.hex(privateKeyBuf);
    }
}
