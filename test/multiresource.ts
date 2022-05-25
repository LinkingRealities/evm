import { Contract } from 'ethers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { MultiResourceToken, ResourceStorage } from '../typechain';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe('MultiResource', async () => {
  let storage: ResourceStorage;
  let storage2: ResourceStorage;
  let token: MultiResourceToken;

  let owner: SignerWithAddress;
  let addrs: any[];

  const emptyOverwrite = ethers.utils.hexZeroPad('0x0', 16);
  const name = 'RmrkTest';
  const symbol = 'RMRKTST';
  const resourceName = 'ResourceA';
  const resourceName2 = 'ResourceB';

  const srcDefault = 'src';
  const thumbDefault = 'thumb';
  const metaURIDefault = 'metaURI';
  const customDefault = ethers.utils.hexZeroPad('0x2222', 8);

  beforeEach(async () => {
    const [signersOwner, ...signersAddr] = await ethers.getSigners();
    owner = signersOwner;
    addrs = signersAddr;

    const Storage = await ethers.getContractFactory('ResourceStorage');
    storage = await Storage.deploy(resourceName);
    await storage.deployed();

    storage2 = await Storage.deploy(resourceName2);
    await storage2.deployed();

    const Token = await ethers.getContractFactory('MultiResourceToken');
    token = await Token.deploy(name, symbol, resourceName);
    await token.deployed();
  });

  describe('Init', async function () {
    it('Name', async function () {
      expect(await token.name()).to.equal(name);
    });

    it('Symbol', async function () {
      expect(await token.symbol()).to.equal(symbol);
    });

    it('Resource Storage Name', async function () {
      expect(await storage.getResourceName()).to.equal(resourceName);
    });
  });

  describe('Resource storage', async function () {
    it('can add resource', async function () {
      const id = ethers.utils.hexZeroPad('0x1111', 8);
      const src = 'src';
      const thumb = 'thumb';
      const metaURI = 'metaURI';
      const custom = ethers.utils.hexZeroPad('0x2222', 8);

      await storage.addResourceEntry(id, src, thumb, metaURI, custom);
    });

    it('cannot get non existing resource', async function () {
      const id = ethers.utils.hexZeroPad('0x1111', 8);
      await expect(storage.getResource(id)).to.be.revertedWith('RMRK: No resource matching Id');
    });

    it('cannot overwrite resource', async function () {
      const id = ethers.utils.hexZeroPad('0x1111', 8);
      const src = 'src';
      const thumb = 'thumb';
      const metaURI = 'metaURI';
      const custom = ethers.utils.hexZeroPad('0x2222', 8);

      await storage.addResourceEntry(id, src, thumb, metaURI, custom);
      await expect(
        storage.addResourceEntry(id, 'newSrc', thumb, metaURI, custom),
      ).to.be.revertedWith('RMRK: resource already exists');
    });
  });

  describe('Adding resources', async function () {
    it('can add resource to token', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const resId2 = ethers.utils.hexZeroPad('0x0002', 8);
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await addResources([resId, resId2]);
      await expect(token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite))
        .to.emit(token, 'ResourceAddedToToken')
        .withArgs(tokenId, '0xd11a4eb9ea936027e0cd9a71fb295090');
      await expect(token.addResourceToToken(tokenId, storage.address, resId2, emptyOverwrite))
        .to.emit(token, 'ResourceAddedToToken')
        .withArgs(tokenId, '0xcda4ed4d2f23058bf8ef918994254dab');

      const pending = await token.getFullPendingResources(tokenId);
      expect(pending).to.be.eql([
        [resId, srcDefault, thumbDefault, metaURIDefault, customDefault],
        [resId2, srcDefault, thumbDefault, metaURIDefault, customDefault],
      ]);
    });

    it('cannot add non existing resource to token', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await expect(
        token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite),
      ).to.be.revertedWith('RMRK: No resource matching Id');
    });

    it('cannot add resource to non existing token', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const tokenId = 1;

      await addResources([resId]);
      await expect(
        token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite),
      ).to.be.revertedWith('ERC721: owner query for nonexistent token');
    });

    it('cannot add resource twice to the same token', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await addResources([resId]);
      await token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite);
      await expect(
        token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite),
      ).to.be.revertedWith('MultiResource: Resource already exists on token');
    });

    it('cannot add too many resources to the same token', async function () {
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      for (let i = 1; i <= 128; i++) {
        const resId = ethers.utils.hexZeroPad(ethers.utils.hexValue(i), 8);
        await addResources([resId]);
        await token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite);
      }

      // Now it's full, next should fail
      const resId = ethers.utils.hexZeroPad(ethers.utils.hexValue(129), 8);
      await addResources([resId]);
      await expect(
        token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite),
      ).to.be.revertedWith('MultiResource: Max pending resources reached');
    });

    it('can add resources from different storages to token', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const resId2 = ethers.utils.hexZeroPad('0x0002', 8);
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await addResources([resId]);
      await addResources([resId2], storage2);
      await token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite);
      await token.addResourceToToken(tokenId, storage2.address, resId2, emptyOverwrite);

      const pending = await token.getFullPendingResources(tokenId);
      expect(pending).to.be.eql([
        [resId, srcDefault, thumbDefault, metaURIDefault, customDefault],
        [resId2, srcDefault, thumbDefault, metaURIDefault, customDefault],
      ]);
    });
  });

  describe('Accepting resources', async function () {
    it('can accept resource', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await addResources([resId]);
      await token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite);
      await expect(token.acceptResource(tokenId, 0)).to.emit(token, 'ResourceAccepted');

      const pending = await token.getFullPendingResources(tokenId);
      expect(pending).to.be.eql([]);
    });

    it('cannot accept resource twice', async function () {
      const resId = ethers.utils.hexZeroPad('0x0001', 8);
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await addResources([resId]);
      await token.addResourceToToken(tokenId, storage.address, resId, emptyOverwrite);
      await token.acceptResource(tokenId, 0);

      await expect(token.acceptResource(tokenId, 0)).to.be.revertedWith(
        'MultiResource: index out of bounds',
      );
    });

    it('cannot accept non existing resource', async function () {
      const tokenId = 1;

      await token.mint(owner.address, tokenId);
      await expect(token.acceptResource(tokenId, 0)).to.be.revertedWith(
        'MultiResource: index out of bounds',
      );
    });
  });

  async function addResources(ids: string[], useStorage?: ResourceStorage): Promise<void> {
    ids.forEach(async (resId) => {
      if (useStorage !== undefined) {
        await useStorage.addResourceEntry(
          resId,
          srcDefault,
          thumbDefault,
          metaURIDefault,
          customDefault,
        );
      } else {
        // Use default
        await storage.addResourceEntry(
          resId,
          srcDefault,
          thumbDefault,
          metaURIDefault,
          customDefault,
        );
      }
    });
  }
});
