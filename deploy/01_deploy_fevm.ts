import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
const { ethers } = require("hardhat");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const {deployments, getNamedAccounts} = hre;
	const {deploy} = deployments;
	
	const {deployer} = await getNamedAccounts();
	console.log("deployer: ", deployer);
	// console.log("provider: ", hre.ethers.provider);
	// const Unitroller = await deploy("Unitroller", {from: deployer, gasLimit: 50000000, args: []});
	const Unitroller = await deploy("Unitroller", {from: deployer, args: []});
	// const Unitroller = await ethers.getContract('Unitroller');
	console.log("Unitroller deployed: ", Unitroller.address);
	const Comptroller = await deploy("Comptroller", {from: deployer, args: []});
	console.log("Comptroller deployed: ", Comptroller.address);
	const UnitrollerInstance = await ethers.getContractAt("Unitroller", Unitroller.address, await ethers.getSigner(deployer));
	const ComptrollerInstance = await ethers.getContractAt("Comptroller", Comptroller.address, await ethers.getSigner(deployer));
	console.log("Done to get contract instances.");
	const admin = await UnitrollerInstance.admin();
	console.log("admin: ", admin);
    await UnitrollerInstance._setPendingImplementation(Comptroller.address);
	console.log("Done to set pendingImplementation");
    await ComptrollerInstance._become(Unitroller.address);
	console.log("Done to connect Unitroller to Comptroller");

	// 2 * 60 * 24 * 365 (BlockTime: 3s)
	let blocksPerYear = 1051200; 
	const baseRatePerYear = 0.03e18.toString();
    const multiplierPerYear = 0.3e18.toString();
    const jumpMultiplierPerYear = 5e18.toString();
    const kink = 0.95e18.toString();
    const reserveFactor = 0.2e18.toString();
	const CommonJumpRateModel = await deploy("CommonJumpRateModel", {from: deployer, args: [blocksPerYear, baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink, deployer]});
	console.log("CommonJumpRateModel deployed: ", CommonJumpRateModel.address);

	const MockWFIL = await deploy("MockWFIL", {from: deployer, args: []});
	console.log("MockWFIL deployed: ", MockWFIL.address);

	const CWrappedNativeDelegate = await deploy("CWrappedNativeDelegate", {from: deployer, args: []});
	console.log("CWrappedNativeDelegate deployed: ", CWrappedNativeDelegate.address);
	const CWrappedNativeDelegator = await deploy("CWrappedNativeDelegator", {from: deployer, args: [MockWFIL.address, Unitroller.address, CommonJumpRateModel.address, 0.02e18.toString(), "Atomax FIL", "aFIL", 18, deployer, CWrappedNativeDelegate.address, "0x00"]});
	console.log("CWrappedNativeDelegator deployed: ", CWrappedNativeDelegator.address);
	const CWrappedNativeDelegateInstance = await ethers.getContractAt("CWrappedNativeDelegate", CWrappedNativeDelegator.address, await ethers.getSigner(deployer));

	const proxiedComptroller = await ethers.getContractAt("Comptroller", Unitroller.address, await ethers.getSigner(deployer));
	await CWrappedNativeDelegateInstance._setReserveFactor(reserveFactor);
	console.log("Done to setReserveFactor to ", reserveFactor, " for ", CWrappedNativeDelegator.address);
	await proxiedComptroller._supportMarket(CWrappedNativeDelegator.address);
	console.log("Done to support market ", CWrappedNativeDelegator.address);

	const FilSmartOwnerFactory = await deploy("FilSmartOwnerFactory", {from: deployer, args: []});
	console.log("Done to deploy FilSmartOwnerFactory: ", FilSmartOwnerFactory.address);
};
export default func;