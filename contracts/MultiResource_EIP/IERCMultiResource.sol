/// @title ERC-**** Multi-Resource Token Standard
/// @dev See https://eips.ethereum.org/EIPS/********
///  Note: the ERC-165 identifier for this interface is 0x********.
pragma solidity ^0.8.9;

interface IERCMultiResource {

    struct Resource {
      bytes8 id;
      string src;
      string thumb;
      string metadataURI;
      bytes custom;
    }


    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);


    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    //see isApprovedForAll
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);


    function balanceOf(address _owner) external view returns (uint256);


    function ownerOf(uint256 _tokenId) external view returns (address);


    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) external;


    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;


    function transferFrom(address _from, address _to, uint256 _tokenId) external;


    function approve(address _approved, uint256 _tokenId) external;


    function setApprovalForAll(address _operator, bool _approved) external;


    function getApproved(uint256 _tokenId) external view returns (address);

    //May not be included in the standard -- needs review
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);


    //RMRK STUFF BELOW HERE

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

    /*
    @notice Returns every resource object for a given tokenId.
    @param _tokenId the token to query for a resource array
    @return an array of Resource objects
    */
    function getFullResources(uint256 _tokenId) external view returns (IResourceStorage.Resource[] memory);

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
