const { expect } = require("chai");
const { ethers } = require("hardhat");
const {utils} = require("ethers");
const {MYTE_TOKEN_CONTRACT,COMMUNITY_CONTRACT,
OWNED_CONTRACT,CONTROLLED_CONTRACT,DEVELOPER_CONTRACT,
INVESTOR_CONTRACT,PEPPER_GUILD_CONTRACT,STAKING_CONTRACT,
TOKEN_CONTRIBUTION_CONTRACT} = require('../constant');
const { mnemonicToEntropy } = require("ethers/lib/utils");
const tokenURL ="https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu";


let controlled;
let owned;
let myteToken;
let communityTreasure;
let developerTreasure;
let investorTreasure;
let pepperGuildTreasure;
let stakingContract;
let tokenContribution;
let nftToken;
let owner;
let addr1;
let addr2;
let addr3;


describe("Contract...",function(){

    beforeEach(async function(){
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

        const contractControlled = await ethers.getContractFactory(CONTROLLED_CONTRACT);
        controlled = await contractControlled.deploy();
        await controlled.deployed();

        const contractOwned = await ethers.getContractFactory(OWNED_CONTRACT);
        owned = await contractOwned.deploy();
        await owned.deployed();

        const contractToken = await ethers.getContractFactory(MYTE_TOKEN_CONTRACT);
        myteToken = await contractToken.deploy();
        await myteToken.deployed();

        const contractCommunity = await ethers.getContractFactory(COMMUNITY_CONTRACT);
        communityTreasure = await contractCommunity.deploy();
        await communityTreasure.deployed();

        const contractInvestor = await ethers.getContractFactory(INVESTOR_CONTRACT);
        investorTreasure = await contractInvestor.deploy();
        await investorTreasure.deployed();

        const contractDeveloper = await ethers.getContractFactory(DEVELOPER_CONTRACT);
        developerTreasure = await contractDeveloper.deploy();
        await developerTreasure.deployed();

        const contractPepper = await ethers.getContractFactory(PEPPER_GUILD_CONTRACT);
        pepperGuildTreasure = await contractPepper.deploy();
        await pepperGuildTreasure.deployed();

           // NFT token creation
       const nftTokenContract = await ethers.getContractFactory('PepperNFT');
       nftToken = await nftTokenContract.deploy();
       await nftToken.deployed();
       console.log("address...",nftToken.address);
        const contractStaking = await ethers.getContractFactory(STAKING_CONTRACT);
        stakingContract = await contractStaking.deploy(nftToken.address,myteToken.address);
        await stakingContract.deployed();

        const contractTokenContribution = await ethers.getContractFactory(TOKEN_CONTRIBUTION_CONTRACT);
        tokenContribution = await contractTokenContribution.deploy();
        await myteToken.changeController(tokenContribution.address);
  
        let deployed;
        await tokenContribution.deployed().then(async(instance) =>{
            deployed = instance;
           await deployed.initialize(
                myteToken.address,
                investorTreasure.address,
                communityTreasure.address,
                developerTreasure.address,
                pepperGuildTreasure.address,
                stakingContract.address
            )
        }).then(async()=>{
            await tokenContribution.finalize();
        });

    
       // mint first NFT
       await nftToken.mint(addr3.address,201689,tokenURL);
       // mint second NFT
       await nftToken.mint(addr3.address,201684,tokenURL);

       expect(await nftToken.ownerOf(201689)).to.equal(addr3.address);
       expect(await nftToken.ownerOf(201684)).to.equal(addr3.address);

    })

    it("Checks initial parameters", async () => {
        expect(await myteToken.controller()).to.equal(tokenContribution.address);
      });
    
    it("Should check maxSupply and balance of the deployed contracts",async function(){
        expect(await myteToken.totalSupply()).to.equal(utils.parseEther('3000000000'));
        expect(await myteToken.balanceOf(investorTreasure.address)).to.equal(utils.parseEther("450000000"));
        expect(await myteToken.balanceOf(communityTreasure.address)).to.equal(utils.parseEther("450000000"));
        expect(await myteToken.balanceOf(developerTreasure.address)).to.equal(utils.parseEther("300000000"));
        expect(await myteToken.balanceOf(pepperGuildTreasure.address)).to.equal(utils.parseEther("900000000"));
        expect(await myteToken.balanceOf(stakingContract.address)).to.equal(utils.parseEther("900000000"));
    })

    it("Should stake NFT into staking contract",async function(){
       
        // It must be approved to move NFT token by approve of IERC721 interface

        await nftToken.connect(addr3).approve(stakingContract.address,201689);
        await nftToken.connect(addr3).approve(stakingContract.address,201684);


        // stake NFT
        // stake first nft
        await stakingContract.connect(addr3).stake(201689,30);
        //stake second nft
        await stakingContract.connect(addr3).stake(201684,60);

        

        // check staked NFT in staking contract
        expect(await nftToken.ownerOf(201689)).to.equal(stakingContract.address);
        expect(await nftToken.ownerOf(201684)).to.equal(stakingContract.address);


        // unstake nft

        await stakingContract.connect(addr3).unstake(201689);

        // check unstaked nft in addr3

         expect(await nftToken.ownerOf(201689)).to.equal(addr3.address);
        

        // get count

         // expect(await stakingContract.connect(addr3).getStakedToken()).to.equal(2);



    })
})