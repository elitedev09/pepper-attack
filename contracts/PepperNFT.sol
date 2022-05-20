// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

 contract PepperNFT is ERC721URIStorage{
  constructor() ERC721("MockPepper", "PEEP") {}

   function mint(address _to,uint256 _tokenId,string memory _tokenURI) external{
       _mint(_to,_tokenId);
       _setTokenURI(_tokenId,_tokenURI);

   }
}