## Simple Summary
A standard interface for multi-resource non-fungible tokens.

## Abstract

The following standard allows for the implementation of a standard API for multi-resource NFTs -- NFTs which incorporate the ability to add, delete, redirect, and modify their corresponding resources. This implementation may be thought of as an extension for ERC721 and is ERC721 compatible, though a full interface including both ERC721 and Multi-Resource functions is provided below for completeness.

## Motivation

There are many cases in which a non-fungible token may benefit from limited mutability, chief among them the need to point to a variety of resources when interacting with a variety of platforms or protocols. With multi-resource tokens, users and collection managers alike can add or rearrange token resource data to serve content to new platforms, hold multiple media references on a single token, as well as manage resources according to a priority system to be able to present different media references to an external renderer in a user-controlled way. This implementation also allows for storing generic data packets on top of these references for use in gaming, governance, defi, etc.

## Specification

```
/// @title ERC-**** Multi-Resource Token Standard
/// @dev See https://eips.ethereum.org/EIPS/********
///  Note: the ERC-165 identifier for this interface is 0x********.
pragma solidity ^0.8.9;

interface IERCMultiResource /* is ERC721 */ {

    struct Resource {
      bytes8 id;
      string src;
      string thumb;
      string metadataURI;
      bytes custom;
    }

    struct LocalResource {
        address resourceAddress;
        bytes8 resourceId;
    }

    /*
    @notice Adds a resource to the pendingResources array of a token.
    @dev In order to be considered valid for rendering, the resource must be
      approved by the user via the acceptResource function. Pending resources
      are capped at a length of 128 for grief prevention.
    @param _tokenId the Id of the token to add a resource to.
    @param _resourceAddress the address of the contract storing the resource
    @param _resouceId the bytes8 identifier of the resource as it exists on the
      target contract
    @param _overwrites optional parameter to signal that, on acceptance, this
      resource will overwrite another resource already present in the
      acceptedResources array
    */
    function addResourceToToken(uint256 _tokenId, address _resourceAddress, bytes8 _resourceId, bytes16 _overwrites) external;

    /*
    @notice Accepts the resouce from pending.
    @dev Moves the resource from the pending array to the accepted array. Array
      order is not preserved.
    @param _tokenId the token to accept a resource
    @param _resourceIndex the index of the resource to accept
    */
    function acceptResource(uint256 _tokenId, uint256 resourceIndex) external;

    /*
    @notice Reject a resource, dropping it from the pending array.
    @dev Drops the resource from the pending array. Array order is not preserved.
    @param _tokenId the token to reject a resource
    @param _resourceIndex the index of the resource to reject
    */
    function rejectResource(uint256 _tokenId, uint256 resourceIndex) external;

    /*
    @notice Reject all resources, clearing the pending array.
    @dev Sets the pending array to empty.
    @param _tokenId the token to reject a resource
    */
    function rejectAllResources(uint256 _tokenId) external;

    /*
    @notice Set the priority of the active resources array.
    @dev Priorities have a 1:1 relationship with their corresponding index in
      the active resources array. E.G, a priority array of [1, 3, 2] indicates
      that the the active resource at index 1 of the active resource array
      has a priority of 1, index 2 has a priority of 3, and index 3 has a priority
      of 2. There is no validation on priority value input; out of order indexes
      must be handled by the frontend. The length of the _priorities array must
      be equal to the present length of the active resources array.
    @param _tokenId the token of the resource priority to set
    @param _priorities An array of priorities to set.
    */
    function setPriority(uint256 _tokenId, uint16[] memory _priorities) external;

    /*
    @notice Returns an array of byte16 identifiers from the active resources
      array for resource lookup.
    @dev Each bytes16 resource corresponds to a local mapping of
      (bytes16 => (address, bytes8)), where address is the address of a
      resource storage contract, and bytes8 is the id of the relevant resource
      on that storage contract. See addResourceEntry dev comment for rationale.
    @param _tokenId the token of the active resource set to get
    @return an array of bytes16 local resource ids corresponding to active resources
    */
    function getActiveResources(uint256 _tokenId) external view returns(bytes16[] memory);

    /*
    @notice Returns an array of byte16 identifiers from the pending resources
      array for resource lookup.
    @dev Each bytes16 resource corresponds to a local mapping of
      (bytes16 => (address, bytes8)), where address is the address of a
      resource storage contract, and bytes8 is the id of the relevant resource
      on that storage contract. See addResourceEntry dev comment for rationale.
    @param _tokenId the token of the active resource set to get
    @return an array of bytes16 local resource ids corresponding to pending resources
    */
    function getPendingResources(uint256 _tokenId) external view returns(bytes16[] memory);

    /*
    @notice Returns the local resource associated with its bytes16 key.
    @dev The localResource struct consists of an address and a bytes8, corresponding to the
      resource storage contract and the bytes8 key of the resource on that contract.
    @param _resourceKey a bytes16 identifier for a local resource object
    @return a LocalResource object
    */
    function getLocalResource(bytes16 _resourceKey) public virtual view returns(LocalResource memory);

    /*
    @notice Returns the resource object from a target resource storage contract.
    @param _storage the address of the resource storage contract
    @param _id the bytes8 identifier of the resource to query
    @return a resource object
    */
    function getResourceObject(address _storage, bytes8 _id) public virtual view returns (IResourceStorage.Resource memory);

    /*
    @notice Returns an array of uint16 resource priorities
    @dev No checking is done on resource priority ranges, sorting must be
      handled by the frontend.
    @param _tokenId the token of the active resource set to get
    @return an array of uint16 resource priorities corresponding to active resources
    */
    function getActiveResourcePriorities(uint256 _tokenId) external view returns(uint16[] memory);

    /*
    @notice Returns the bytes16 resource ID a given token will overwrite if
      overwrite is enabled for a pending resource.
    @param _tokenId the token of the active pending overwrite
    @param _resId the resource ID which will be potentially overwritten
    @return a bytes16 corresponding to the local resource ID of the resource that will overwrite @param _resId
    */
    function getResourceOverwrites(uint256 _tokenId, bytes16 _resId) external view returns(bytes16);

    /*
    @notice Returns the src field of the first active resource on the token,
      otherwise returns a fallback src.
    @param _tokenId the token to query for a URI
    @return the string URI of the token
    */
    function tokenURI(uint256 _tokenId) external view returns (string memory);

}

interface ERC721 /* is ERC165 */ {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

interface ERC165 {

    function supportsInterface(bytes4 interfaceID) external view returns (bool);

}

interface IResourceStorage {

  struct Resource {
      bytes8 id;
      string src;
      string thumb;
      string metadataURI;
      bytes custom;
  }

  /*
  @notice Adds a resource entry to the resource storage contract.
  @dev Resources are stored on a separate contract and referred to by reference
    for two reasons: generic reference storage on the multiresource token contract
    for variable resource struct types, and to reduce redundant storage on the
    multiresource token contract. With this structure, a generic resource can be
    added once on the storage contract, and a reference to it can be added to it
    once on the token contract. Implementers can then use string concatenation
    to procedurally generate a link to a content-addressed archive based on
    the base SRC in the resource and the token ID. Storing the resource on a new
    token will only take 16 bytes of storage in the resource array per token for
    repeated / tokenID dependent resources.
  @param _id the id of the resource
  @param _src a link to the source of the resource
  @param _thumb a link to a low-resolution thumbnail of the resource
  @param _metadataURI a link the the metadata of the resource
  @param _custom additional data to be stored
  */
  function addResourceEntry(bytes8 _id, string memory _src, string memory _thumb, string memory _metadataURI, bytes memory _custom) external;

  /*
  @notice Returns the resource at the id.
  @dev Exact struct data types are left to the implementer
  @param _resourceId the id of the resource to return
  */
  function getResource(bytes8 _resourceId) external view returns (Resource memory);

}

```

## Rationale

#Backward Compatibility
The Multi Resource token standard has been based on existing ERC721 implementations in order to take advantage of the robust tooling available for ERC721 implementations and to ensure compatibility with existing ERC721 infrastructure.

#Resource fields

#Multi-Resource Storage Schema
Resources are stored on a token as an array of bytes16 identifiers.

In order to reduce redundant on-chain string storage, multi resource tokens store resources by reference via a secondary storage contract. A resource entry on the storage contract is stored via a bytes8 mapping to resource data. A bytes16 identifier is then computed from the hash of (address storageContractAddress, bytes8 resourceId). Both address and bytes8 identifier are then stored on the local contract as a bytes16 mapping to this reference.

A resource array is an array of these bytes16 references. This ensures that for tokens that share common features and can be easily identified by their tokenId may share a single resource, and URIs may be derived programmatically through string concatenation.

#Propose-Commit pattern for resource addition
Adding resources to an existing token takes the form of a propose-commit pattern to allow for limited mutability by a 3rd party. When adding a resource to a token, it is first placed in the "Pending" array, and must be migrated to the "Active" array by the token owner. The "Pending" resources array is limited to 128 slots to prevent spam.

#Resource management
Several functions for resource management are included. In addition to permissioned migration from "Pending" to "Active", the owner of a token may also drop resources from both the active and the pending array -- an emergency function to clear all entries from the pending array is also included.

##TODO:
Fallback Resource

#Resource initialization



## Develop

Just run `npx hardhar compile` to check if it works. Refer to the rest below.

This project demonstrates an advanced Hardhat use case, integrating other tools commonly used alongside Hardhat in the ecosystem.

The project comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts. It also comes with a variety of other tools, preconfigured to work with the project code.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

## Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
hardhat run --network ropsten scripts/sample-script.ts
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS "Hello, Hardhat!"
```

# Performance optimizations

For faster runs of your tests and scripts, consider skipping ts-node's type checking by setting the environment variable `TS_NODE_TRANSPILE_ONLY` to `1` in hardhat's environment. For more details see [the documentation](https://hardhat.org/guides/typescript.html#performance-optimizations).
