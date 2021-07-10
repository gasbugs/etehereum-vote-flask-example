// SPDX-License-Identifier: GPL-3.0
// pragma solidity >=0.7.0 <0.9.0;
/// @title Voting with delegation.
contract Ballot {
    // This declares a new complex type which will
    // be used for variables later.
    // It will represent a single voter.
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
    }

    // This is a type for a single proposal.
    struct Proposal {
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    address public chairperson;

    // This declares a state variable that
    // stores a `Voter` struct for each possible address.
    mapping(address => Voter) public voters;

    // A dynamically-sized array of `Proposal` structs.
    Proposal[] public proposals;
    
    /// 초기화 코드
    /// 'proposalNames' 중 하나를 선택하려면 새 투표지를 만드세요.
    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        // 제공된 각 제안 이름에 대해 새 제안 개체를 만들고 배열 끝에 추가합니다.
        for (uint i = 0; i < proposalNames.length; i++) {
            // `Proposal({...})` creates a temporary
            // Proposal object and `proposals.push(...)`
            // appends it to the end of `proposals`.
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }
    
    function getVoter() public view returns(uint, bool, address, uint) {
        Voter storage sender = voters[msg.sender];
        return (sender.weight, sender.voted, sender.delegate, sender.vote);
    }
    
    function getProposalsCount() public view returns(uint) {
        return proposals.length;
    }
    
    function getProposal(uint index) public view returns(bytes32, uint) {
        return (proposals[index].name, proposals[index].voteCount);
    }
    
    function isChairperson() public view returns(bool) {
        if ( msg.sender == chairperson ) {
            return false;
        }
        return true;
    }

    // '투표자'에게 이 투표용지에 대한 투표권을 부여합니다.
    // '의장'만 호출할 수 있습니다.
    function giveRightToVote(address voter) public {
        // `require`의 첫 번째 인수가 `false`로 평가되면 실행이 종료되고 상태 및
        // Ether 잔액에 대한 모든 변경 사항이 되돌려집니다.
        // 이것은 이전 EVM 버전에서 모든 가스를 소비하는 데 사용되었지만 더 이상은 아닙니다.
        // 종종 `require`를 사용하여 함수가 올바르게 호출되었는지 확인하는 것이 좋습니다.
        // 두 번째 인수로 무엇이 잘못되었는지에 대한 설명을 제공할 수도 있습니다.
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[voter].voted,
            "The voter already voted."
        );
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    /// 투표자 'to'에게 투표를 위임합니다.
    function delegate(address to) public {
        // 참조 할당
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "You already voted.");

        require(to != msg.sender, "Self-delegation is disallowed.");

        
        // `to`도 위임된 한 위임을 전달합니다.
        // 일반적으로 이러한 루프는 너무 오래 실행되면 블록에서 사용할 수 있는 것보다 
        // 더 많은 가스가 필요할 수 있기 때문에 매우 위험합니다.
        // 이 경우 위임이 실행되지 않지만 다른 상황에서는 이러한 루프로 인해 계약이 완전히 "고착"될 수 있습니다.
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // 위임에서 허용되지 않는 루프를 찾았습니다.
            require(to != msg.sender, "Found loop in delegation.");
        }

        // Since `sender` is a reference, this
        // modifies `voters[msg.sender].voted`
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your vote (including votes delegated to you)
    /// to proposal `proposals[proposal].name`.
    function vote(uint proposal) public {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = proposal;

        // If `proposal` is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposal].voteCount += sender.weight;
    }

    /// @dev Computes the winning proposal taking all
    /// previous votes into account.
    function winningProposal() public view
            returns (uint winningProposal_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    // Calls winningProposal() function to get the index
    // of the winner contained in the proposals array and then
    // returns the name of the winner
    function winnerName() public view
            returns (bytes32 winnerName_)
    {
        winnerName_ = proposals[winningProposal()].name;
    }
}