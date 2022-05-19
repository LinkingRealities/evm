// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import "./interfaces/IRMRKResourceCore.sol";
import "./interfaces/IRMRKResourceStorage.sol";
import "./RMRKResourceCore.sol";
import "./library/RMRKLib.sol";

contract RMRKMultiResource {

  using RMRKLib for uint256;
  using RMRKLib for bytes16[];
  using Strings for uint256;

  struct Resource {
    IRMRKResourceCore resourceAddress;
    bytes8 resourceId;
  }

  //mapping resourceContract to resource entry
  mapping(bytes16 => Resource) private _resources;

  //mapping tokenId to current resource to replacing resource
  mapping(uint256 => mapping(bytes16 => bytes16)) private _resourceOverwrites;

  //mapping of tokenId to all resources by priority
  mapping(uint256 => bytes16[]) private _activeResources;

  //mapping of tokenId to an array of resource priorities
  mapping(uint256 => uint16[]) private _activeResourcePriorities;

  //Double mapping of tokenId to active resources
  mapping(uint256 => mapping(bytes16 => bool)) private _tokenResources;

  //Double mapping of tokenId to active resources -- experimental bytes17 using abi.encodePacked of ID and boolean
  //Save on a keccak256 call of double mapping
  mapping(uint256 => bytes17) private _tokenResourcesExperimental;

  //mapping of tokenId to all resources by priority
  mapping(uint256 => bytes16[]) private _pendingResources;

  //Mapping of bytes8 resource ID to tokenEnumeratedResource for tokenURI
  mapping(bytes8 => bool) private _tokenEnumeratedResource;

  // AccessControl roles and nest flag constants
  RMRKResourceCore public resourceStorage;

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
  constructor(string memory resourceName) {
    resourceStorage = new RMRKResourceCore(resourceName);
  }

  ////////////////////////////////////////
  //              RESOURCES
  ////////////////////////////////////////

  function _addResourceEntry(
      bytes8 _id,
      string memory _src,
      string memory _thumb,
      string memory _metadataURI
  ) internal virtual {
    resourceStorage.addResourceEntry(
      _id,
      _src,
      _thumb,
      _metadataURI
      );
    emit ResourceStorageSet(_id);
  }

  function _addResource(
      uint256 _tokenId,
      IRMRKResourceCore _resourceAddress,
      bytes8 _resourceId,
      bytes16 _overwrites
  ) internal virtual {

      bytes16 localResourceId = hashResource16(_resourceAddress, _resourceId);

      require(
        _tokenResources[_tokenId][localResourceId] == false,
        "RMRKCore: Resource already exists on token"
      );
      //This error code will never be triggered because of the interior call of
      //resourceStorage.getResource. Left in for posterity.

      //Abstract this out to IRMRKResourceStorage
      require(
        resourceStorage.getResource(_resourceId).id != bytes8(0),
        "RMRKCore: Resource not found in storage"
      );

      require(
        _pendingResources[_tokenId].length < 128,
        "RMRKCore: Max pending resources reached"
      );

      //Construct Resource object
      Resource memory resource_ = Resource({
        resourceAddress: _resourceAddress,
        resourceId: _resourceId
      });

      //gas saving if check for repeated resource usage
      if (address(_resources[localResourceId].resourceAddress) == address(0)){
          _resources[localResourceId] = resource_;
      }
      _tokenResources[_tokenId][localResourceId] = true;

      _pendingResources[_tokenId].push(localResourceId);

      if (_overwrites != bytes16(0)) {
        _resourceOverwrites[_tokenId][localResourceId] = _overwrites;
        emit ResourceOverwriteProposed(_tokenId, localResourceId, _overwrites);
      }

      emit ResourceAddedToToken(_tokenId, localResourceId);
  }

  function _acceptResource(uint256 _tokenId, uint256 index) internal virtual {
      bytes16 _localResourceId = _pendingResources[_tokenId][index];
      require(
          address(_resources[_localResourceId].resourceAddress) != address(0),
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

  function _rejectResource(uint256 _tokenId, uint256 index) internal virtual {
      require(
        _pendingResources[_tokenId].length > index,
        "RMRKcore: Pending child index out of range"
      );

      bytes16 _localResourceId = _pendingResources[_tokenId][index];
      _pendingResources[_tokenId].removeItemByValue(_localResourceId);
      _tokenResources[_tokenId][_localResourceId] = false;

      emit ResourceRejected(_tokenId, _localResourceId);
  }

  function _rejectAllResources(uint256 _tokenId) internal virtual {
      delete(_pendingResources[_tokenId]);
      emit ResourceRejected(_tokenId, bytes16(0));
  }

  /*
    Edits a priority array that maps 1-1 to active resources
  */

  function _setPriority(uint256 _tokenId, uint16[] memory _priorities) internal virtual {
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
  function getRenderableResource(uint256 tokenId) public virtual view returns (Resource memory resource) {
      bytes16 resourceId = getActiveResources(tokenId)[0];
      return _resources[resourceId];
  }

  function getResourceObject(IRMRKResourceCore _storage, bytes8 _id) public virtual view returns (IRMRKResourceCore.Resource memory resource) {
      return _storage.getResource(_id);
  }

  /* function getFullResources(uint256 tokenId) public virtual view returns (IRMRKResourceStorage.Resource[] memory) {
      bytes16[] memory activeResources = _activeResources[tokenId];
      uint256 len = activeResources.length;
      IRMRKResourceStorage.Resource[] memory resources;
      for (uint i; i<len;) {
        resources[i] = getResourceObject(_resources[activeResources[i]].resourceAddress, _resources[activeResources[i]].resourceId);
        unchecked {++i;}
      }
      return resources;
  } */

  function getResObjectByIndex(uint256 _tokenId, uint256 _index) public virtual view returns(IRMRKResourceCore.Resource memory resource) {
      bytes16 localResourceId = getActiveResources(_tokenId)[_index];
      Resource memory _resource = _resources[localResourceId];
      (IRMRKResourceCore _storage, bytes8 _id) = (_resource.resourceAddress, _resource.resourceId);
      return getResourceObject(_storage, _id);
  }

  function getResourceOverwrites(uint256 _tokenId, bytes16 _resId) public view returns(bytes16) {
      return _resourceOverwrites[_tokenId][_resId];
  }

  function hashResource16(IRMRKResourceCore _address, bytes8 _id) public pure returns (bytes16) {
      return bytes16(keccak256(abi.encodePacked(_address, _id)));
  }

  function setTokenEnumeratedResource(bytes8 _resourceId, bool state) public virtual {
      _tokenEnumeratedResource[_resourceId] = state;
  }

  function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
      if (_activeResources[tokenId].length > 0)  {
          Resource memory activeRes = _resources[_activeResources[tokenId][0]];
          IRMRKResourceCore resAddr = activeRes.resourceAddress;
          bytes8 resId = activeRes.resourceId;
          string memory URI;
          IRMRKResourceCore.Resource memory _activeRes = IRMRKResourceCore(resAddr).getResource(resId);
          if (!_tokenEnumeratedResource[resId]) {
            return _activeRes.metadataURI;
          }
          else {
            string memory baseURI = _activeRes.metadataURI;
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
          }
      }
      else {
          return _fallbackURI;
    }
  }
}
