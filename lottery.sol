// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is VRFConsumerBaseV2 {
  AggregatorV3Interface internal ethUsdPriceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e); // Rinkeby ETH/USD Data Feed
  VRFCoordinatorV2Interface COORDINATOR;

  enum LOTTERY_STATE{OPEN, CLOSED, CALCULATING_WINNER}
  LOTTERY_STATE public lotteryState;
  // Your subscription ID.
  uint64 s_subscriptionId;
  uint public usdParticipationFee = 50;
  address public recentWinner;
  address payable[] public players;

  event RequestedRandomness(uint requestId);

  // Rinkeby coordinator. For other networks,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

  // Depends on the number of requested values that you want sent to the
  // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
  // so 100,000 is a safe default for this example contract. Test and adjust
  // this limit based on the network that you select, the size of the request,
  // and the processing of the callback request in the fulfillRandomWords()
  // function.
  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
  uint32 numWords =  2;

  uint256[] public s_randomWords;
  uint256 public s_requestId;
  address s_owner;

  constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    s_owner = msg.sender;
    s_subscriptionId = subscriptionId;
    
    lotteryState = LOTTERY_STATE.CLOSED;
  }

  function startLottery() public onlyOwner{
      require(lotteryState == LOTTERY_STATE.CLOSED, "Can't start a new lottery");
      lotteryState = LOTTERY_STATE.OPEN;
      s_randomWords = new uint[](0);
    }

  function participate() public payable{
      require(msg.value >= getParticipationFee(), "Not Enough ETH to participate!");
      require(lotteryState == LOTTERY_STATE.OPEN, "The lottery is closed. Wait until the next lottery");
      players.push(payable(msg.sender));
    }

  function getParticipationFee() public view returns(uint){
        uint precision = 1 * 10 ** 18;
        uint price = uint(getLatestPrice());
        uint costToParticipate = (precision / price) * (usdParticipationFee * 100000000);
        return costToParticipate;
    }

  function getLatestPrice() public view returns(int){
      (
        /*uint80 roundID*/,
        int price,
        /*uint startedAt*/,
        /*uint timeStamp*/,
        /*uint80 answeredInRound*/
        ) = ethUsdPriceFeed.latestRoundData();

        return price;
    }

  function endLottery() public onlyOwner{
        require(lotteryState == LOTTERY_STATE.OPEN, "Can't end lottery yet");
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        pickWinner();
        }
  
  // Assumes the subscription is funded sufficiently.
  function pickWinner() public onlyOwner{
        require(lotteryState == LOTTERY_STATE.CALCULATING_WINNER, "Needs to be calculating the winner");
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
              keyHash,
              s_subscriptionId,
              requestConfirmations,
              callbackGasLimit,
              numWords
             );
         emit RequestedRandomness(s_requestId);
        }

  
  function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    s_randomWords = randomWords;
    require(randomWords[0] > 0, "random number not found");
    uint index = randomWords[0] % players.length;
    players[index].transfer(address(this).balance);
    recentWinner = players[index];
    players = new address payable[](0);
    lotteryState = LOTTERY_STATE.CLOSED;
  }

  modifier onlyOwner() {
    require(msg.sender == s_owner);
    _;
  }

  function getLotteryBalance() public view returns (uint) {
    return address(this).balance;
    }
}
