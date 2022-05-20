//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MyteToken.sol";
import "./Owned.sol";
import "./SafeMath.sol";


contract TokenContribution is Owned {
    using SafeMath for uint256;

    uint256 public constant maxSupply = 3e9 ether;

    MyteToken public token;

    event ControllerChanged(address indexed _newController);

    address public destTokenInvestor;
    address public destTokenCommunity;
    address public destTokenDeveloper;
    address public destTokenPepperGuild;
    address public destTokenStaking;

    uint256 public totalTokenGenerated;

    modifier initialized() {
        require(address(token) != address(0));
        _;
    }
    event Finalize();
    event Initialize(MyteToken _token,address _destTokenInvestor,address _destTokenCommunity,address _destTokenDeveloper,address _destTokenPepperGuild,address _destTokenStaking);

    constructor() {}

    function changeController(address _newController) public onlyOwner {
        token.changeController(_newController);
        emit ControllerChanged(_newController);
    }

    function initialize(
        address _token,
        address _destTokenInvestor,
        address _destTokenCommunity,
        address _destTokenDeveloper,
        address _destTokenPepperGuild,
        address _destTokenStaking
    ) external onlyOwner {
        //Initialize only once
        require(
            address(_token) != address(0),
            "The token address can not be zero."
        );
        token = MyteToken(_token);

        require(address(_destTokenInvestor) != address(0));
        destTokenInvestor = _destTokenInvestor;

        require(address(_destTokenCommunity) != address(0));
        destTokenCommunity = _destTokenCommunity;

        require(address(_destTokenDeveloper) != address(0));
        destTokenDeveloper = _destTokenDeveloper;

        require(address(_destTokenPepperGuild) != address(0));
        destTokenPepperGuild = _destTokenPepperGuild;

        require(address(_destTokenStaking) != address(0));
        destTokenStaking = _destTokenStaking;
      
       emit Initialize(token,destTokenInvestor,destTokenCommunity,destTokenDeveloper,destTokenPepperGuild,destTokenStaking);
  
    }

    function finalize() external initialized onlyOwner {
        uint256 percentageToInvestor = 150;
        uint256 percentageToCommunity = 150;
        uint256 percentageToDeveloper = 100;
        uint256 percentageToPepperGuild = 300;
        uint256 percentageToStaking = 300;

        //
        //                    percentageToInvestor
        //  InvestorTokens = ----------------------- * maxSupply
        //                      1e3
        //

         token.mint(destTokenInvestor, maxSupply * percentageToInvestor / 1e3);
         token.mint(destTokenCommunity, maxSupply * percentageToCommunity / 1e3);
         token.mint(destTokenDeveloper, maxSupply * percentageToDeveloper / 1e3);
         token.mint(destTokenPepperGuild, maxSupply * percentageToPepperGuild / 1e3);
         token.mint(destTokenStaking, maxSupply * percentageToStaking / 1e3);
        emit Finalize();
    }
}
