// SPDX-License-Identifier: MIT
// references
// https://solidity-by-example.org/app/erc20/
// https://solidity-by-example.org/signature/
// https://www.tutorialspoint.com/solidity/solidity_pure_functions.htm
// encrypted email and otp
pragma solidity >=0.8.1;

contract userReg {
    struct userDataDefinition {
        bool register;
        uint registerTime;
        bool registerOtp;
        uint registerOtpStartTime;
        address[] dataAddress;
        string[] data;
    }
    string[] adminPublicKey;
    mapping(bytes => userDataDefinition) public userData;
    error errMsg(string message, address addr, bytes data, bytes signature);
    event userRegister(string caller, address addr, bytes data);

    function isUserRegister(address addr, string memory message, bytes memory signature) public view returns (bool) {
        bool validsig = false;
        bool register = false;

        validsig = verify(addr, message, signature);

        if (validsig && userData[signature].register && (block.timestamp < (userData[signature].registerTime + 24 hours))) {
            register = true;
        }

        return register;
    }

    function newUserRegisterUserStart(bytes[] memory publicKey, bytes[] memory data, string memory message, bytes memory signature) public {
        if (isValidsigPublicKey(publicKey, data, message, signature, "newUserRegisterUserStart") == false)
            return;

        userData[signature].register = false;
        userData[signature].registerTime = block.timestamp;
        userData[signature].registerOtpStartTime = block.timestamp;
    }

    function newUserRegisterUserComplete(bytes[] memory publicKey, bytes[] memory data, string memory message, bytes memory signature) public {
        if (isValidsigPublicKey(publicKey, data, message, signature, "newUserRegisterUserComplete") == false)
            return;

        if (block.timestamp < (userData[signature].registerOtpStartTime + 30 minutes))
            userData[signature].registerOtp = true;
        else
            revert errMsg({message: "newUserRegisterUserOtpExpire", addr: address(bytes20(keccak256(publicKey[0]))), data: data[0], signature: signature});
    }

    function newUserRegisterAdminApprove(bytes[] memory publicKey, bytes[] memory data, string memory message, bytes memory signature) public {
        if (isValidsigPublicKey(publicKey, data, message, signature, "newUserRegisterAdminApprove") == false)
            return;

        userData[signature].register = true;
    }

    function isValidsigPublicKey(bytes[] memory publicKey, bytes[] memory data, string memory message, bytes memory signature, string memory str) private returns (bool) {
        bool validsig = false;
        uint i = 0;
        string memory err = string.concat("invalid signature ", str);
        address[] memory addr;

        for (i = 0; i < publicKey.length; i++)
            addr[i] = address(bytes20(keccak256(publicKey[i])));

        validsig = verify(addr[0], message, signature);

        if (validsig == false)
            revert errMsg({message: err, addr: addr[0], data: data[0], signature: signature});
        else {
            for (i = 0; i < addr.length; i++)
                emit userRegister(str, addr[i], data[i]);
        }

        return validsig;
    }

    function getMessageHash(
        string memory message
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(message));
    }

    function getEthSignedMessageHash(
        bytes32 messageHash
    ) private pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
            );
    }

    function recoverSigner(
        bytes32 ethSignedMessageHash,
        bytes memory signature
    ) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function verify(
        address signer,
        string memory message,
        bytes memory signature
    ) private pure returns (bool) {
        bytes32 messageHash = getMessageHash(message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == signer;
    }
}
