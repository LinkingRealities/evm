// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

/* import "./interfaces/IResourceStorage.sol"; */
import "./interfaces/IMultiResourceReceiver.sol";
import "./RMRKResourceStorage.sol";
import "./library/RMRKLib.sol";
import "./IERCMultiResource.sol";
import "./utils/Address.sol";
import "./utils/Strings.sol";
import "./utils/Context.sol";

contract ERCMultiResourceToken is Context, IERCMultiResource {

  using RMRKLib for uint256;
  using RMRKLib for bytes16[];
  using Address for address;
  using Strings for uint256;

  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  struct LocalResource {
    address resourceAddress;
    bytes8 resourceId;
  }

  //mapping resourceContract to resource entry
  mapping(bytes16 => LocalResource) private _localResources;

  //mapping tokenId to current resource to replacing resource
  mapping(uint256 => mapping(bytes16 => bytes16)) private _resourceOverwrites;

  //mapping of tokenId to all resources by priority
  mapping(uint256 => bytes16[]) private _activeResources;

  //mapping of tokenId to an array of resource priorities
  mapping(uint256 => uint16[]) private _activeResourcePriorities;

  //Double mapping of tokenId to active resources
  mapping(uint256 => mapping(bytes16 => bool)) private _tokenResources;

  //mapping of tokenId to all resources by priority
  mapping(uint256 => bytes16[]) private _pendingResources;

  // AccessControl roles and nest flag constants
  RMRKResourceStorage public resourceStorage;

  string private _fallbackURI;

  //Resource events
  event ResourceStorageSet(bytes8 id);
  event ResourceAddedToToken(uint256 indexed tokenId, bytes16 localResourceId);
  event ResourceAccepted(uint256 indexed tokenId, bytes16 localResourceId);
  //Emits bytes16(0) as localResourceId in the event all resources are deleted
  event ResourceRejected(uint256 indexed tokenId, bytes16 localResourceId);
  event ResourcePrioritySet(uint256 indexed tokenId);
  event ResourceOverwriteProposed(uint256 indexed tokenId, bytes16 localResourceId, bytes16 overwrites);
  event ResourceOverwritten(uint256 indexed tokenId, bytes16 overwritten);

  constructor(string memory name_, string memory symbol_, string memory resourceName_) {
    _name = name_;
    _symbol = symbol_;
    resourceStorage = new RMRKResourceStorage(resourceName_);
  }

  ////////////////////////////////////////
  //        ERC-721 COMPLIANCE
  ////////////////////////////////////////


  function supportsInterface(bytes4 interfaceId) public view returns (bool) {
      return
          interfaceId == type(IERCMultiResource).interfaceId;
  }


  function balanceOf(address owner) public view virtual override returns (uint256) {
      require(owner != address(0), "ERC721: address zero is not a valid owner");
      return _balances[owner];
  }


  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
      address owner = _owners[tokenId];
      require(owner != address(0), "ERC721: owner query for nonexistent token");
      return owner;
  }


  function name() public view virtual returns (string memory) {
      return _name;
  }


  function symbol() public view virtual returns (string memory) {
      return _symbol;
  }


  function approve(address to, uint256 tokenId) public virtual {
      address owner = ownerOf(tokenId);
      require(to != owner, "MultiResource: approval to current owner");

      require(
          _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
          "MultiResource: approve caller is not owner nor approved for all"
      );

      _approve(to, tokenId);
  }


  function getApproved(uint256 tokenId) public view virtual override returns (address) {
      require(_exists(tokenId), "MultiResource: approved query for nonexistent token");

      return _tokenApprovals[tokenId];
  }


  function setApprovalForAll(address operator, bool approved) public virtual override {
      _setApprovalForAll(_msgSender(), operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
      return _operatorApprovals[owner][operator];
  }


  function transferFrom(
      address from,
      address to,
      uint256 tokenId
  ) public virtual override {
      //solhint-disable-next-line max-line-length
      require(_isApprovedOrOwner(_msgSender(), tokenId), "MultiResource: transfer caller is not owner nor approved");

      _transfer(from, to, tokenId);
  }


  function safeTransferFrom(
      address from,
      address to,
      uint256 tokenId
  ) public virtual override {
      safeTransferFrom(from, to, tokenId, "");
  }


  function safeTransferFrom(
      address from,
      address to,
      uint256 tokenId,
      bytes memory data
  ) public virtual override {
      require(_isApprovedOrOwner(_msgSender(), tokenId), "MultiResource: transfer caller is not owner nor approved");
      _safeTransfer(from, to, tokenId, data);
  }

  function _safeTransfer(
      address from,
      address to,
      uint256 tokenId,
      bytes memory data
  ) internal virtual {
      _transfer(from, to, tokenId);
      require(_checkOnMultiResourceReceived(from, to, tokenId, data), "MultiResource: transfer to non MultiResource Receiver implementer");
  }


  function _exists(uint256 tokenId) internal view virtual returns (bool) {
      return _owners[tokenId] != address(0);
  }


  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
      require(_exists(tokenId), "MultiResource: operator query for nonexistent token");
      address owner = ownerOf(tokenId);
      return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
  }


  function _safeMint(address to, uint256 tokenId) internal virtual {
      _safeMint(to, tokenId, "");
  }


  function _safeMint(
      address to,
      uint256 tokenId,
      bytes memory data
  ) internal virtual {
      _mint(to, tokenId);
      require(
          _checkOnMultiResourceReceived(address(0), to, tokenId, data),
          "MultiResource: transfer to non MultiResource Receiver implementer"
      );
  }


  function _mint(address to, uint256 tokenId) internal virtual {
      require(to != address(0), "MultiResource: mint to the zero address");
      require(!_exists(tokenId), "MultiResource: token already minted");

      _beforeTokenTransfer(address(0), to, tokenId);

      _balances[to] += 1;
      _owners[tokenId] = to;

      emit Transfer(address(0), to, tokenId);

      _afterTokenTransfer(address(0), to, tokenId);
  }


  function _burn(uint256 tokenId) internal virtual {
      address owner = ownerOf(tokenId);

      _beforeTokenTransfer(owner, address(0), tokenId);

      // Clear approvals
      _approve(address(0), tokenId);

      _balances[owner] -= 1;
      delete _owners[tokenId];

      emit Transfer(owner, address(0), tokenId);

      _afterTokenTransfer(owner, address(0), tokenId);
  }


  function _transfer(
      address from,
      address to,
      uint256 tokenId
  ) internal virtual {
      require(ownerOf(tokenId) == from, "MultiResource: transfer from incorrect owner");
      require(to != address(0), "MultiResource: transfer to the zero address");

      _beforeTokenTransfer(from, to, tokenId);

      // Clear approvals from the previous owner
      _approve(address(0), tokenId);

      _balances[from] -= 1;
      _balances[to] += 1;
      _owners[tokenId] = to;

      emit Transfer(from, to, tokenId);

      _afterTokenTransfer(from, to, tokenId);
  }


  function _approve(address to, uint256 tokenId) internal virtual {
      _tokenApprovals[tokenId] = to;
      emit Approval(ownerOf(tokenId), to, tokenId);
  }


  function _setApprovalForAll(
      address owner,
      address operator,
      bool approved
  ) internal virtual {
      require(owner != operator, "MultiResource: approve to caller");
      _operatorApprovals[owner][operator] = approved;
      emit ApprovalForAll(owner, operator, approved);
  }


  function _checkOnMultiResourceReceived(
      address from,
      address to,
      uint256 tokenId,
      bytes memory data
  ) private returns (bool) {
      if (to.isContract()) {
          try MultiResourceTokenReceiver(to).onMultiResourceReceived(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
              return retval == MultiResourceTokenReceiver.onMultiResourceReceived.selector;
          } catch (bytes memory reason) {
              if (reason.length == 0) {
                  revert("MultiResource: transfer to non MultiResource Receiver implementer");
              } else {
                  assembly {
                      revert(add(32, reason), mload(reason))
                  }
              }
          }
      } else {
          return true;
      }
  }


  function _beforeTokenTransfer(
      address from,
      address to,
      uint256 tokenId
  ) internal virtual {}


  function _afterTokenTransfer(
      address from,
      address to,
      uint256 tokenId
  ) internal virtual {}

  ////////////////////////////////////////
  //              RESOURCES
  ////////////////////////////////////////

  function _addResourceEntry(
      bytes8 _id,
      string memory _src,
      string memory _thumb,
      string memory _metadataURI,
      bytes memory _custom
  ) internal virtual {
    resourceStorage.addResourceEntry(
      _id,
      _src,
      _thumb,
      _metadataURI,
      _custom
      );
    emit ResourceStorageSet(_id);
  }

  function addResourceToToken(
      uint256 _tokenId,
      address _resourceAddress,
      bytes8 _resourceId,
      bytes16 _overwrites
  ) external virtual {

      bytes16 localResourceId = hashResource16(_resourceAddress, _resourceId);

      require(
        _tokenResources[_tokenId][localResourceId] == false,
        "RMRKCore: Resource already exists on token"
      );
      //This error code will never be triggered because of the interior call of
      //resourceStorage.getResource. Left in for posterity.

      //Abstract this out to IResourceStorage
      require(
        resourceStorage.getResource(_resourceId).id != bytes8(0),
        "RMRKCore: Resource not found in storage"
      );

      require(
        _pendingResources[_tokenId].length < 128,
        "RMRKCore: Max pending resources reached"
      );

      //Construct Resource object
      LocalResource memory resource_ = LocalResource({
        resourceAddress: _resourceAddress,
        resourceId: _resourceId
      });

      //gas saving if check for repeated resource usage
      if (address(_localResources[localResourceId].resourceAddress) == address(0)){
          _localResources[localResourceId] = resource_;
      }
      _tokenResources[_tokenId][localResourceId] = true;

      _pendingResources[_tokenId].push(localResourceId);

      if (_overwrites != bytes16(0)) {
        _resourceOverwrites[_tokenId][localResourceId] = _overwrites;
        emit ResourceOverwriteProposed(_tokenId, localResourceId, _overwrites);
      }

      emit ResourceAddedToToken(_tokenId, localResourceId);
  }

  function acceptResource(uint256 _tokenId, uint256 index) external {
      bytes16 _localResourceId = _pendingResources[_tokenId][index];
      require(
          address(_localResources[_localResourceId].resourceAddress) != address(0),
          "RMRK: resource does not exist"
      );

      _pendingResources[_tokenId].removeItemByIndex(0);

      bytes16 overwrite = _resourceOverwrites[_tokenId][_localResourceId];
      if (overwrite != bytes16(0)) {
        // We could check here that the resource to overwrite actually exists but it is probably harmless.
        _activeResources[_tokenId].removeItemByValue(overwrite);
        emit ResourceOverwritten(_tokenId, overwrite);
      }
      _activeResources[_tokenId].push(_localResourceId);
      //Push 0 value of uint16 to array, e.g., uninitialized
      _activeResourcePriorities[_tokenId].push(uint16(0));
      emit ResourceAccepted(_tokenId, _localResourceId);
  }

  function rejectResource(uint256 _tokenId, uint256 index) external {
      require(
        _pendingResources[_tokenId].length > index,
        "RMRKcore: Pending child index out of range"
      );

      bytes16 _localResourceId = _pendingResources[_tokenId][index];
      _pendingResources[_tokenId].removeItemByValue(_localResourceId);
      _tokenResources[_tokenId][_localResourceId] = false;

      emit ResourceRejected(_tokenId, _localResourceId);
  }

  function rejectAllResources(uint256 _tokenId) external virtual {
      delete(_pendingResources[_tokenId]);
      emit ResourceRejected(_tokenId, bytes16(0));
  }

  /*
    Edits a priority array that maps 1-1 to active resources
  */

  function setPriority(uint256 _tokenId, uint16[] memory _priorities) external {
      uint256 length = _priorities.length;
      require(
        length == _activeResources[_tokenId].length,
          "RMRK: Bad priority list length"
      );
      _activeResourcePriorities[_tokenId] = _priorities;

      emit ResourcePrioritySet(_tokenId);
  }

  function getActiveResources(uint256 tokenId) public virtual view returns(bytes16[] memory) {
      return _activeResources[tokenId];
  }

  function getPendingResources(uint256 tokenId) public virtual view returns(bytes16[] memory) {
      return _pendingResources[tokenId];
  }

  function getActiveResourcePriorities(uint256 tokenId) public virtual view returns(uint16[] memory) {
      return _activeResourcePriorities[tokenId];
  }

  //Deprecate
  function getRenderableResource(uint256 tokenId) public virtual view returns (LocalResource memory) {
      bytes16 resourceId = getActiveResources(tokenId)[0];
      return _localResources[resourceId];
  }

  function getResourceObject(address _storage, bytes8 _id) public virtual view returns (IResourceStorage.Resource memory) {
      return IResourceStorage(_storage).getResource(_id);
  }

  function getResObjectByIndex(uint256 _tokenId, uint256 _index) public virtual view returns(IResourceStorage.Resource memory) {
      bytes16 localResourceId = getActiveResources(_tokenId)[_index];
      LocalResource memory _localResource = _localResources[localResourceId];
      (address _storage, bytes8 _id) = (_localResource.resourceAddress, _localResource.resourceId);
      return getResourceObject(_storage, _id);
  }

  function getFullResources(uint256 tokenId) public virtual view returns (IResourceStorage.Resource[] memory) {
      bytes16[] memory activeResources = _activeResources[tokenId];
      uint256 len = activeResources.length;
      IResourceStorage.Resource[] memory resources;
      for (uint i; i<len;) {
        resources[i] = getResourceObject(_localResources[activeResources[i]].resourceAddress, _localResources[activeResources[i]].resourceId);
        unchecked {++i;}
      }
      return resources;
  }

  function getResourceOverwrites(uint256 _tokenId, bytes16 _resId) public view returns(bytes16) {
      return _resourceOverwrites[_tokenId][_resId];
  }

  function hashResource16(address _address, bytes8 _id) public pure returns (bytes16) {
      return bytes16(keccak256(abi.encodePacked(_address, _id)));
  }

  function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
      if (_activeResources[tokenId].length > 0)  {
          LocalResource memory activeRes = _localResources[_activeResources[tokenId][0]];
          address resAddr = activeRes.resourceAddress;
          bytes8 resId = activeRes.resourceId;

          IResourceStorage.Resource memory _activeRes = IResourceStorage(resAddr).getResource(resId);
          string memory URI = _activeRes.src;
          return URI;
      }
      else {
          return _fallbackURI;
    }
  }
}
