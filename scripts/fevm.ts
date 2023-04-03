import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
const { ethers } = require("hardhat");

async function main() {
    const abi = [
        "function getSectorSize() external view returns (uint64)",
        "function getAvailableBalance() external view returns (tuple(bytes,bool))",
        "function getBeneficiary() external view returns (tuple(tuple(tuple(bytes),tuple(tuple(bytes,bool),tuple(bytes,bool),uint64)),tuple(tuple(bytes),tuple(bytes,bool),uint64,bool,bool)))",
        "function getPeerId() external view returns (tuple(bytes))",
        "function getMultiaddresses() external view returns (tuple(tuple(bytes)[]))",
        "function isControllingAddress(address controller) external view returns (bool)",
        "function getMinerOwner() external view returns (address currentOwner, address proposedOwner)"
      ];
	// const MinerSmartOwnerInstance = await ethers.getContractAt(abi, "0x399f514132cb1DBF8169bE9ead39c33555A1F00c", await ethers.getSigner("0x2280C50eF73550b7Ac71AaCd1d6485B3120c2c46"));
    const MinerSmartOwnerInstance = await ethers.getContractAt(abi, "0x0331718Ef5150841a4AfA6d7870E5d77CD2c743A", await ethers.getSigner("0x2280C50eF73550b7Ac71AaCd1d6485B3120c2c46"));
    const sectorSize = await MinerSmartOwnerInstance.getSectorSize();
	console.log("sectorSize: ", sectorSize.toString());
    const getAvailableBalance = await MinerSmartOwnerInstance.getAvailableBalance();
	console.log("getAvailableBalance: ", getAvailableBalance.toString());
    const getBeneficiary = await MinerSmartOwnerInstance.getBeneficiary();
	console.log("getBeneficiary: ", getBeneficiary);
    const getPeerId = await MinerSmartOwnerInstance.getPeerId();
	console.log("getPeerId: ", getPeerId);
    const getMultiaddresses = await MinerSmartOwnerInstance.getMultiaddresses();
	console.log("getMultiaddresses: ", getMultiaddresses);
    const isControllingAddress = await MinerSmartOwnerInstance.isControllingAddress("0x399f514132cb1DBF8169bE9ead39c33555A1F00c");
	console.log("isControllingAddress: ", isControllingAddress);
    const minerOwner = await MinerSmartOwnerInstance.getMinerOwner();
    console.log("minerOwner: ", minerOwner);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
