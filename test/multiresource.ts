import { Contract } from 'ethers';
import { ethers } from 'hardhat';
import {    expect } from 'chai';
import { MultiResourceToken, ResourceStorage } from '../typechain';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';


describe('MultiResource', async () => {
    let storage: ResourceStorage;
    let token: MultiResourceToken;

    let owner: SignerWithAddress;
    let addrs: any[];

    const name = 'RmrkTest';
    const symbol = 'RMRKTST';
    const resourceName = 'TestResource';

    beforeEach(async () => {
        const [signersOwner, ...signersAddr] = await ethers.getSigners();
        owner = signersOwner;
        addrs = signersAddr;

        const Storage = await ethers.getContractFactory('ResourceStorage');
        storage = await Storage.deploy(resourceName);
        await storage.deployed();

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

    describe("Resource Storage", async function () {
        it("can add resource", async function () {
            const id = ethers.utils.hexZeroPad('0x1111', 8);
            const src = "src";
            const thumb = "thumb";
            const metaURI = "metaURI";
            const custom = ethers.utils.hexZeroPad('0x2222', 8);

            await storage.addResourceEntry(id, src, thumb, metaURI, custom);

        });

        it("cannot get non existing resource", async function () {
            const id = ethers.utils.hexZeroPad('0x1111', 8);
            await expect(storage.getResource(id)).to.be.revertedWith("RMRK: No resource matching Id")
        });


        it("cannot overwrite resource", async function () {
            const id = ethers.utils.hexZeroPad('0x1111', 8);
            const src = "src";
            const thumb = "thumb";
            const metaURI = "metaURI";
            const custom = ethers.utils.hexZeroPad('0x2222', 8);

            await storage.addResourceEntry(id, src, thumb, metaURI, custom);
            await expect(storage.addResourceEntry(id, "newSrc", thumb, metaURI, custom)).to.be.revertedWith("RMRK: resource already exists")
        });
    });
});