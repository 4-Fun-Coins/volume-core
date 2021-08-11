# Volume Marketplace Contract

## This contract acts as the marketplace where users can trade their NFTs - whether it be the AstroPunks or the other NFTs given as rewards.

Users are able to list an NFT for a certain price decided prior to the listing. The owner of the listing is able to remove the listing, as well as change the price of the listing. 

The listing has a reentrancy lock, so if any interaction is made with the listing, like the price is being updated, or the NFT is being bought, the price can not be changed nor can the listing be removed.

The contract will hold custody of the NFT, and only the owner can take it back or if it gets purchased, the contract will transfer it to the new owner after receiving the funds from the buyer. There will be a small amount taken from the transaction that will be burned, and the balance will be sent to the seller.

In the case where the NFT gets bought directly from Volume, the majority of the sale amount will be burned for fuel and the rest will go to the treasury.

# Volume NFTFactory Contract

## This contract is the minter for all the NFTs.

Using this contract we will be able to add categories and the NFTs that go with each of them. We can never remove a category.

The sole reason for this contract is that users can feel comfortable knowing that whatever NFTs get minted to this contract will be listed on the marketplace immediately.

# Volume EnumerableNFT Contract

## This is one of the main NFT types we will have - a series of NFTs that belong to a certain category.

The first NFT range we are going to release will be the AstroPunks - a series of really cute astronauts that the community can buy and trade using the Marketplace.