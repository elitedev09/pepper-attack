//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './IERC721.sol';
interface IERC721Metadata is IERC721{
   
   //Returns the token collection name.
   function name() external view returns(string memory);

   // Returns the token collection symbol.
   function symbol() external view returns(string memory);

   // Returns the Uniform Resource Identifier (URI) for the 'tokenId' token
   function tokenURI(uint256 tokenId) external view returns(string memory);
}