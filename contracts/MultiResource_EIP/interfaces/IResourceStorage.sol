// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface IResourceStorage {
    struct Resource {
        bytes8 id; //8 bytes
        string src; //32+
        string thumb; //32+
        string metadataURI; //32+
        bytes custom;
    }

    function addResourceEntry(
        bytes8 _id,
        string memory _src,
        string memory _thumb,
        string memory _metadataURI,
        bytes memory _custom
    ) external;

    function getResource(bytes8 resourceId)
        external
        view
        returns (Resource memory);
}
