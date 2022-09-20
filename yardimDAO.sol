// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/IERC721A.sol";

contract yardimDAO {
    struct Proposal {
        uint yayVotes;
        uint nayVotes;
        uint deadline;

        address to;
        string description;

        mapping(uint => bool) voters;
        mapping(address => uint) addressToFundedAmount;
        bool executed;
        uint totalFunded;
    }

    mapping(uint => Proposal) public proposals;
    uint numberOfProposals;
    IERC721A daoNFT;

    constructor(address _nft){
        daoNFT = IERC721A(_nft);
    }

    enum Vote {
        yay, // 0
        nay // 1
    }

    modifier nftHolderOnly() {
        require(daoNFT.balanceOf(msg.sender)>0,"not a DAO member");
        _;
    }

    modifier activeProposalOnly(uint _proposalIndex) {
        require(block.timestamp < proposals[_proposalIndex].deadline, "proposal is not active");
        _;
    }

    modifier successfulProposalOnly(uint _proposalIndex) {
        require(block.timestamp > proposals[_proposalIndex].deadline, "not yet");
        _;
        require(proposals[_proposalIndex].yayVotes > proposals[_proposalIndex].nayVotes, "not much successful");
    }

    modifier rejectedProposalOnly(uint _proposalIndex) {
        require(block.timestamp > proposals[_proposalIndex].deadline, "not yet");
        _;
        require(proposals[_proposalIndex].yayVotes <= proposals[_proposalIndex].nayVotes, "proposal is successful");
    }

    function createProposal(address _to, string memory _description) external nftHolderOnly {
        Proposal storage proposal = proposals[numberOfProposals];
        proposal.to = _to;
        proposal.description = _description;
        proposal.deadline = block.timestamp + 5 minutes;

        numberOfProposals ++;
    }

    function voteOnProposal(Vote vote, uint proposalIndex, uint[] memory NFTsToVote)
    external
    nftHolderOnly 
    activeProposalOnly(proposalIndex)
    payable
    {
        uint votePower = NFTsToVote.length;

        require(votePower > 0, "show some NFTs to vote");

        Proposal storage proposal = proposals[proposalIndex];

        for(uint i; i<votePower; i++){
            require(daoNFT.ownerOf(NFTsToVote[i]) == msg.sender, "you need to own the NFT");
            require(!proposal.voters[NFTsToVote[i]],"this NFT has already used to vote");
            proposal.voters[NFTsToVote[i]] = true; 
        }

        if(vote == Vote.yay){
            proposal.yayVotes += votePower;
            proposal.addressToFundedAmount[msg.sender] += msg.value;
            proposal.totalFunded += msg.value;
        }
        if(vote == Vote.nay){
            proposal.nayVotes += votePower;
        }
    }

    function executeProposal(uint proposalIndex) external nftHolderOnly successfulProposalOnly(proposalIndex){
        Proposal storage proposal = proposals[proposalIndex];

        require(!proposal.executed, "proposal is already executed");

        proposal.executed = true;
        (bool success,) = proposal.to.call{value:proposal.totalFunded}("");
        require(success, "transfer failed");
    }

    function retrieveFunds(uint proposalIndex) external nftHolderOnly rejectedProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        uint funded = proposal.addressToFundedAmount[msg.sender];

        require(funded > 0, "you have not funded");

        proposal.addressToFundedAmount[msg.sender] -= funded;
        (bool success,) = msg.sender.call{value:funded}("");
        require(success, "transfer failed");
    }

    receive() external payable {}

    fallback() external payable {}
}
