// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

interface IRMRKNestingInternal {
    function ownerOf(uint256 tokenId)
        external view returns (address owner);

    function rmrkOwnerOf(uint256 tokenId)
       external view returns (
           address,
           uint256,
           bool
       );

    function _burnChildren(uint256 tokenId, address oldOwner) external;

    function setChild(
        address childTokenAddress,
        uint256 tokenId,
        uint256 childTokenId
    ) external;

    function setChildAccepted(
        address childTokenAddress,
        uint256 tokenId,
        uint256 childTokenId
    ) external;

    function rejectChild(
        uint256 index,
        uint256 tokenId
    ) external;

    function deleteChildFromChildren(
        uint256 index,
        uint256 tokenId
    ) external;
}
