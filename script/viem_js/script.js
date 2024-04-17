import { abi, avalance, base, contractNFTNogem, op, scroll } from "./info.js";
import { arbitrum, bsc, celo, gnosis, manta, moonbeam, polygon } from "viem/chains";
import * as ethers from "ethers";
import { createPublicClient, createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import chalk from "chalk";

class SetEnroll {
  constructor(private_key, chain) {
    this.signer = createWalletClient({ chain: chain, account: privateKeyToAccount(this.handlerPrivateKey(privateKey)), transport: http(), });
    this.reader = createPublicClient({ chain: chain, transport: http() });
    this.chain = chain;
  }

  async delay(seconds) {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
  }

  handlerPrivateKey(privateKey) {
    return privateKey.startsWith("0x") ? privateKey : `0x${privateKey}`;
  }

  async setEnrollRouters(contract_address, chain_ids, addresses) {
    console.log(
      chalk.magentaBright(`Start set enroll rutes in chain id ${chain_ids}`),
    );
    try {
      let tx = await this.signer.writeContract({
        address: contract_address,
        abi: abi,
        functionName: "enrollRemoteRouters",
        args: [chain_ids, addresses],
      });
      console.log(chalk.greenBright(`Enroll transaction successfully >> ${tx}`))
      return tx;
    } catch (e) {
      console.log(chalk.red(e));
    }
  }
  async createParamsForTx(contract, startingChainId) {
    let chain_ids = [];
    let addresses = [];

    Object.keys(contract).forEach((chainId) => {
      console.log(contract[chainId]);
      if (chainId !== startingChainId) {
        chain_ids.push(parseInt(chainId));
        addresses.push(ethers.utils.hexZeroPad(contract[chainId], 32));
      }
    });

    console.log(JSON.stringify(chain_ids), JSON.stringify(addresses));
    return { chain_ids, addresses };
  }

  async set_enroll(contract, startingChainId) {
    const { chain_ids, addresses } = await this.createParamsForTx(
      contract,
      startingChainId,
    );
    const contract_address = contract[startingChainId];
    await this.setEnrollRouters(contract_address, chain_ids, addresses);
  }
}

const privateKey =
  "0x9c8d112c471f44993f04cdfc61a5cf522a934f11938fc98ce3c80c384e6e79bb";

const hypr = new SetEnroll(privateKey, arbitrum);

// hypr.set_enroll(contractNFTNogem, "88");
//hypr.createParamsForTx(contract, "42220", privateKey);