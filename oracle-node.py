# Setup
import json
import time
#import os
from web3 import Web3
from solcx import compile_standard, install_solc


#

# Read the Solidity code from the Carpooling.sol file
with open("./contracts/Carpooling.sol", "r") as file:
#with open(file_path, "r") as file:
    carpooling_file = file.read()

# Print a message and install Solidity compiler version 0.8.0
print("Installing...")
install_solc("0.8.0")

# Compile the Solidity code
compiled_sol = compile_standard(
    {
        "language": "Solidity",
        "sources": {"./contracts/Carpooling.sol": {"content": carpooling_file}},
        "settings": {
            "outputSelection": {"": {"": ["abi", "metadata", "evm.bytecode", "evm.sourceMap"]}}
        },
    },
    solc_version="0.8.0",
)
print(compiled_sol)

# Alchemy API URL and other constants
ALCHEMY_URL = "https://eth-sepolia.g.alchemy.com/v2/V3sYnEkDEQYHqFAekAZpgtzmzIfp5tTC"
MY_ACCOUNT = "0x745Cc1955a1c935CdfE6B4f7c95c0505bd4Eea3F"
PRIVATE_KEY = bytes.fromhex("18ed5aed317d1fc56f64211206cab4eb5e6d50ee9c56c6cdd94a2417553cece2")
CARPOOLING_SOURCE = "./contracts/Carpooling.sol"

# Function to compile the Solidity contract
def compile_contract(w3):
    with open(CARPOOLING_SOURCE, 'r') as file:
        carpooling_code = file.read()

    compiled_sol = compile_standard(
        {
            "language": "Solidity",
            "sources": {CARPOOLING_SOURCE: {"content": carpooling_code}},
            "settings": {
                "outputSelection": {"*": {"*": ["abi", "metadata", "evm.bytecode", "evm.sourceMap"]}}
            },
        },
        solc_version="0.8.0",
    )

    print("Compilation Result:")
    print(compiled_sol)

    contract_name = CARPOOLING_SOURCE.split("/")[-1].split(".")[0]
    contract_interface = compiled_sol["contracts"][CARPOOLING_SOURCE][contract_name]

    bytecode = contract_interface["evm"]["bytecode"]["object"]
    abi = contract_interface["abi"]

    Contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    print("Compile completed!")
    return Contract

# Function to deploy the Solidity contract
def deploy_carpooling(w3, contract):
    deploy_txn = contract.constructor().build_transaction({
        'gas': 2000000,
        'gasPrice': w3.to_wei('30', 'gwei'),
        'nonce': w3.eth.get_transaction_count(MY_ACCOUNT),
    })

    signed_txn = w3.eth.account.sign_transaction(deploy_txn, private_key=PRIVATE_KEY)
    print("Deploying Contract...")
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    print("Transaction Hash:", tx_hash)

    txn_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print("Transaction Receipt:", txn_receipt)

    carpooling_address = txn_receipt['contractAddress']
    print("Carpooling contract deployed at:", carpooling_address)
    return carpooling_address

# Function to join a ride in the carpooling contract
def join_ride(w3, contract, ride_id):
    contract_address = contract.address
    join_txn = contract.functions.joinRide(ride_id).build_transaction({
        'gas': 2000000,
        'gasPrice': w3.to_wei('30', 'gwei'),
        'nonce': w3.eth.get_transaction_count(MY_ACCOUNT),
        'to': contract_address,
    })

    signed_txn = w3.eth.account.sign_transaction(join_txn, private_key=PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)

    txn_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    return txn_receipt

# Main function
def main():
    w3 = Web3(Web3.HTTPProvider(ALCHEMY_URL))
    w3.eth.default_account = MY_ACCOUNT

    if not w3.is_connected():
        print('Not connected to Alchemy endpoint')
        exit(-1)

    CarpoolingContract = compile_contract(w3)
    CarpoolingContract.address = deploy_carpooling(w3, CarpoolingContract)
    print("Carpooling contract address:")
    print(CarpoolingContract.address)

    # Assume there's a ride with ID 1 that a passenger wants to join
    ride_id_to_join = 1
    txn_receipt = join_ride(w3, CarpoolingContract, ride_id_to_join)
    print("Transaction complete!")
    print("blockNumber:", txn_receipt.blockNumber, "gasUsed:", txn_receipt.gasUsed)

if __name__ == "__main__":
    main()
