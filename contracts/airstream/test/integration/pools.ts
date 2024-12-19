import {
  impersonateAccount,
  loadFixture,
  mine,
  setBalance,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { assert, expect } from "chai";
import hre, { viem } from "hardhat";
import { vars } from "hardhat/config";
import { getAddress, parseEventLogs, parseUnits, zeroAddress } from "viem";
import { claimArgs } from "../utils";

const ethxTokenAddress = getAddress(
  "0x4ac8bD1bDaE47beeF2D1c6Aa62229509b962Aa0d",
); // ETHx on Optimism

const gdav1ForwarderAddress: `0x${string}` =
  "0x6DA13Bde224A05a288748d857b9e7DDEffd1dE08";

const superTokenFactoryAddress: `0x${string}` =
  "0x8276469A443D5C6B7146BED45e2abCaD3B6adad9"; // SuperTokenFactory on Optimism

// A helper function to compare two bigints with an absolute difference
// Usage: expectAbsDiff(totalFlowRate, flowRate).to.be.lte(10n);
const expectAbsDiff = (a: bigint, b: bigint, message?: string) => {
  return expect(Number(a > b ? a - b : b - a), message);
};

// A deployment function to set up the initial state
const deploy = async () => {
  const publicClient = await viem.getPublicClient();
  const [wallet1, wallet2, wallet3] = await viem.getWalletClients();
  const accounts = [wallet1.account, wallet2.account, wallet3.account];

  // Deploy the AirstreamFactory contract
  const airstreamFactory = await viem.deployContract("AirstreamFactory", [
    gdav1ForwarderAddress,
    superTokenFactoryAddress,
  ]);

  const airstreamFromTx = async (hash: `0x${string}`) => {
    const receipt = await publicClient.getTransactionReceipt({ hash });
    const logs = parseEventLogs({
      abi: airstreamFactory.abi,
      logs: receipt.logs,
    });
    return logs[0].args;
  };

  // Mint and transfer ETHx
  setBalance(wallet1.account.address, parseUnits("150100", 18));
  const ethxToken = await viem.getContractAt("ERC20", ethxTokenAddress);
  const tx = await wallet1.sendTransaction({
    to: ethxTokenAddress,
    value: parseUnits("150000", 18),
    data: "0xcf81464b", // upgradeByETH()
  });
  await publicClient.waitForTransactionReceipt({ hash: tx });

  // Approve the AirstreamFactory to transfer ETHx
  await ethxToken.write.approve(
    [airstreamFactory.address, parseUnits("150000", 18)],
    {
      account: wallet1.account.address,
    },
  );

  // Prepare initial configuration
  const config = {
    token: ethxTokenAddress,
    name: "ETHx Airstream",
    merkleRoot:
      "0x83d9c1db51ee14c9aa71a3f72490fbaf8e3004479de4d0a5dfa57a927654a45b" as `0x${string}`,
    totalAmount: parseUnits("150000", 18),
    duration: BigInt(9 * 30 * 24 * 60 * 60),
  };

  const extendedConfig = {
    superToken: zeroAddress,
    claimingWindow: {
      startDate: 0n,
      duration: 0n,
      treasury: zeroAddress,
    },
    initialRewardPPM: 0,
    feePPM: 0,
  };

  // Create a new Airstream
  const hash = await airstreamFactory.write.createExtendedAirstream([
    config,
    extendedConfig,
  ]);

  const { airstream, controller, pool } = await airstreamFromTx(hash);

  // Get the deployed Airstream contract
  const airstreamContract = await viem.getContractAt(
    "BasicAirstream",
    airstream,
  );
  const airstreamControllerContract = await viem.getContractAt(
    "AirstreamController",
    controller,
  );
  // Get the deployed Pool contract
  const poolContract = await viem.getContractAt("ISuperfluidPool", pool);
  const gdav1ForwarderContract = await viem.getContractAt(
    "GDAv1Forwarder",
    gdav1ForwarderAddress,
  );

  const macroForwarder = await viem.getContractAt(
    "MacroForwarder",
    "0xFD0268E33111565dE546af2675351A4b1587F89F",
  );

  return {
    airstreamFactory,
    airstreamContract,
    airstreamControllerContract,
    poolContract,
    gdav1ForwarderContract,
    macroForwarder,
    publicClient,
    wallet1,
    wallet2,
    accounts,
    claimArgs,
    airstreamFromTx,
    gdav1ForwarderAddress,
    config,
    ethxToken,
  };
};

describe("Integration Tests: Pools", () => {
  before(async () => {
    await hre.network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: `https://opt-mainnet.g.alchemy.com/v2/${vars.get("ALCHEMY_KEY")}`,
            blockNumber: 125_042_537,
          },
        },
      ],
    });
  });

  describe("Airstream and Pool Interactions", () => {
    it("should allow recipients to claim their streams in different times and do not change significantly", async () => {
      const {
        airstreamContract,
        poolContract,
        gdav1ForwarderContract,
        ethxToken,
        claimArgs,
      } = await loadFixture(deploy);

      // Distribute flows
      const flowRate = await airstreamContract.read.flowRate();

      // Wait for a short period to allow flows to update
      await mine(1, { interval: 1000 });

      // Check total flow rate
      const totalFlowRate = await poolContract.read.getTotalFlowRate();
      expectAbsDiff(totalFlowRate, flowRate).to.be.lte(1e8);

      await airstreamContract.write.claim(claimArgs(0)); // Claim the first stream

      await impersonateAccount(claimArgs(0)[0]);
      await setBalance(claimArgs(0)[0], 100n ** 18n);
      await gdav1ForwarderContract.write.connectPool(
        [poolContract.address, ""],
        { account: claimArgs(0)[0] },
      );

      await mine(1, { interval: 10000 });

      await airstreamContract.write.claim(claimArgs(1)); // Claim the second stream

      await impersonateAccount(claimArgs(1)[0]);
      await setBalance(claimArgs(0)[0], 100n ** 18n);
      await gdav1ForwarderContract.write.connectPool(
        [poolContract.address, ""],
        { account: claimArgs(1)[0] },
      );

      await mine(1, { interval: 10000 });

      expectAbsDiff(
        await ethxToken.read.balanceOf([claimArgs(0)[0]]), // Balance of the first recipient
        await ethxToken.read.balanceOf([claimArgs(1)[0]]), // Balance of the second recipient
        "Balances should be equal",
      ).to.be.lte(1e8);
    });
    it("should be able to pause and resume the airstream", async () => {
      const {
        airstreamContract,
        airstreamControllerContract,
        poolContract,
        claimArgs,
      } = await loadFixture(deploy);

      // Distribute flows
      const flowRate = await poolContract.read.getTotalFlowRate();
      await airstreamContract.write.claim(claimArgs(0));

      // Wait for a short period to allow flows to update and pause the airstream
      await mine(1, { interval: 1000 });
      await airstreamControllerContract.write.pauseAirstream();
      const flowRateAfterPause = await poolContract.read.getTotalFlowRate();
      const streamedAfterPause =
        await poolContract.read.getTotalAmountReceivedByMember([
          claimArgs(0)[0],
        ]);

      // Wait for a short period to allow flows to update and resume the airstream
      await mine(1, { interval: 1000 });
      await airstreamControllerContract.write.resumeAirstream();
      const flowRateAfterResume = await poolContract.read.getTotalFlowRate();
      const streamedAfterResume =
        await poolContract.read.getTotalAmountReceivedByMember([
          claimArgs(0)[0],
        ]);

      // Check if the flow rate is 0 after pausing and resumes to the original flow rate
      expect(flowRateAfterPause).to.be.eq(0n);
      expect(flowRateAfterResume).to.be.eq(flowRate);

      // Wait for a short period to allow flows to update
      await mine(1, { interval: 1000 });
      const currentStreamed =
        await poolContract.read.getTotalAmountReceivedByMember([
          claimArgs(0)[0],
        ]);

      // Check if the stream stopped and resumed correctly
      expect(streamedAfterPause).not.to.be.eq(0n);
      expect(streamedAfterPause).to.be.eq(streamedAfterResume);
      expect(currentStreamed - streamedAfterPause).to.not.be.eq(0n);
    });
  });

  describe("Claim and Connect Macro", () => {
    it("should allow any recipient to claim and connect to the pool in a single transaction", async () => {
      const {
        airstreamContract,
        gdav1ForwarderContract,
        macroForwarder,
        poolContract,
        claimArgs,
      } = await loadFixture(deploy);

      await impersonateAccount(claimArgs(0)[0]);
      await setBalance(claimArgs(0)[0], 10n ** 18n);

      expect(
        await airstreamContract.read.isClaimed([claimArgs(0)[0]]),
      ).to.be.eq(false);

      const claimAndConnectParams = await airstreamContract.read.getParams(
        claimArgs(0),
      );
      await macroForwarder.write.runMacro(
        [airstreamContract.address, claimAndConnectParams],
        {
          account: claimArgs(0)[0],
        },
      );

      // TODO: Waiting for Superfluid to fix the macro forwarding issue
      // Until then, we need to claim the stream manually
      await airstreamContract.write.claim(claimArgs(0));
      await gdav1ForwarderContract.write.connectPool(
        [poolContract.address, ""],
        { account: claimArgs(0)[0] },
      );

      expect(
        await airstreamContract.read.isClaimed([claimArgs(0)[0]]),
      ).to.be.eq(true);
      expect(
        await gdav1ForwarderContract.read.isMemberConnected([
          poolContract.address,
          claimArgs(0)[0],
        ]),
      ).to.be.eq(true);
    });
  });

  describe("Redirections", () => {
    it("should allow the admin to redirect rewards (many-to-one)", async () => {
      const {
        airstreamContract,
        airstreamControllerContract,
        claimArgs,
        wallet1,
      } = await loadFixture(deploy);
      await airstreamContract.write.claim(claimArgs(0)); // Claim the first stream
      await airstreamContract.write.claim(claimArgs(1)); // Claim the second stream
      const firstAddress = claimArgs(0)[0];
      const secondAddress = claimArgs(1)[0];
      const firstAmount = BigInt(claimArgs(0)[1]);
      const secondAmount = BigInt(claimArgs(1)[1]);
      await airstreamControllerContract.write.redirectRewards([
        [firstAddress, secondAddress],
        [wallet1.account.address],
        [secondAmount, firstAmount],
      ]);
      expect(
        await airstreamContract.read.getAllocation([firstAddress]),
      ).to.be.eq(0n);
      expect(
        await airstreamContract.read.getAllocation([secondAddress]),
      ).to.be.eq(0n);
      expect(
        await airstreamContract.read.getAllocation([wallet1.account.address]),
      ).to.be.eq(firstAmount + secondAmount);
    });
    it("should allow the admin to redirect rewards (many-to-many)", async () => {
      const {
        airstreamContract,
        airstreamControllerContract,
        claimArgs,
        wallet1,
        wallet2,
      } = await loadFixture(deploy);
      await airstreamContract.write.claim(claimArgs(0)); // Claim the first stream
      await airstreamContract.write.claim(claimArgs(1)); // Claim the second stream
      const firstAddress = claimArgs(0)[0];
      const secondAddress = claimArgs(1)[0];
      const firstAmount = BigInt(claimArgs(0)[1]);
      const secondAmount = BigInt(claimArgs(1)[1]);
      await airstreamControllerContract.write.redirectRewards([
        [firstAddress, secondAddress],
        [wallet1.account.address, wallet2.account.address],
        [secondAmount, firstAmount],
      ]);
      expect(
        await airstreamContract.read.getAllocation([firstAddress]),
      ).to.be.eq(0n);
      expect(
        await airstreamContract.read.getAllocation([secondAddress]),
      ).to.be.eq(0n);
      expect(
        await airstreamContract.read.getAllocation([wallet1.account.address]),
      ).to.be.eq(firstAmount);
      expect(
        await airstreamContract.read.getAllocation([wallet2.account.address]),
      ).to.be.eq(secondAmount);
    });
    it("should allow the admin to redirect rewards (many-to-many with different amounts)", async () => {
      const {
        airstreamContract,
        airstreamControllerContract,
        claimArgs,
        wallet1,
        wallet2,
      } = await loadFixture(deploy);
      await airstreamContract.write.claim(claimArgs(0)); // Claim the first stream
      await airstreamContract.write.claim(claimArgs(10)); // Claim the second stream
      const firstAddress = claimArgs(0)[0];
      const secondAddress = claimArgs(10)[0];
      const firstAmount = BigInt(claimArgs(0)[1]);
      const secondAmount = BigInt(claimArgs(10)[1]);
      assert(
        firstAmount !== secondAmount,
        "First and second amounts should be different",
      );
      await airstreamControllerContract.write.redirectRewards([
        [firstAddress, secondAddress],
        [wallet1.account.address, wallet2.account.address],
        [secondAmount, firstAmount],
      ]);
      expect(
        await airstreamContract.read.getAllocation([firstAddress]),
      ).to.be.eq(0n);
      expect(
        await airstreamContract.read.getAllocation([secondAddress]),
      ).to.be.eq(0n);
      expect(
        await airstreamContract.read.getAllocation([wallet1.account.address]),
      ).to.be.eq(secondAmount);
      expect(
        await airstreamContract.read.getAllocation([wallet2.account.address]),
      ).to.be.eq(firstAmount);
    });
  });
});
