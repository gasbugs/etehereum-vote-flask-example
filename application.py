from flask import Flask, render_template
from web3 import Web3
from solcx import compile_source
from flask import request


# 컴파일 함수
def compile_source_file(file_path):
    with open(file_path, 'r') as f:
        source = f.read()
    return compile_source(source)


# 컨트랙트 배포 후 해당 컨트랙트의 주소를 반환하는 코드
def deploy_contract(w3, contract_interface):
    candidates = [b'Rama', b'Niki', b'Jose']
    tx_hash = w3.eth.contract(
        abi=contract_interface['abi'],
        bytecode=contract_interface['bin']).constructor(candidates).transact()
    address = w3.eth.get_transaction_receipt(tx_hash)['contractAddress']
    return address


ip = '175.198.224.248'
w3 = Web3(Web3.HTTPProvider(f'http://{ip}:7545'))
print('web3 접속:', w3.isConnected())

if w3.isConnected() == False:
    exit()


# 블록정보획득
# print(w3.eth.get_block(0))

# 1. sol 파일에서 계약을 컴파일한다.
vote_source_path = 'vote.sol'
compiled_sol = compile_source_file(vote_source_path)
contract_id, contract_interface = compiled_sol.popitem()
w3.eth.defaultAccount = w3.eth.accounts[0]

contract_address = deploy_contract(w3, contract_interface)
print(f'Deployed {contract_id} to: {contract_address}\n')

vote_contract = w3.eth.contract(address=contract_address, abi=contract_interface["abi"])

application = Flask(__name__)


@application.route("/")
def index():
    proposal_length = vote_contract.functions.getProposalsCount().call()
    proposals = []

    for i in range(proposal_length):
        proposal = vote_contract.functions.getProposal(i).call()
        proposals.append(proposal)

    winnerName = vote_contract.functions.winnerName().call()
    winnerName = winnerName.decode()

    voter_info = vote_contract.functions.getVoter().call()

    # print(contract_interface["abi"])
    return render_template('index.html', proposals=proposals,
                           contract_address=contract_address,
                          abi=contract_interface["abi"],
                          winnerName=winnerName,
                          voter_info=voter_info)


@application.route("/give_right_to_vote")
def give_right_to_vote():
    give_address = request.args.get('give_address')
    my_address = request.args.get('my_address')
    if my_address:
        my_address = Web3.toChecksumAddress(my_address)
    
    if w3.eth.defaultAccount != my_address:
        # print('address 불일치')
        return render_template('no_right_vote.html')
    if not give_address:
        return render_template('give_right_to_vote.html')
    else:
        try:
            tx_hash = vote_contract.functions.giveRightToVote(give_address).transact()
            amount = w3.toWei(1, 'ether') #  1 ether를 wei로 단위 변경
            tx_hash = w3.eth.sendTransaction({
                'from': my_address,
                'to': give_address,
                'value': amount
            })

        except Exception as e:
            print('ERROR!', e)

        return render_template('give_right_to_vote.html', give_address=give_address)

@application.route("/delegate")
def delegate():
    delegate_address = request.args.get('delegate_address')
    return render_template('delegate.html',
                           delegate_address=delegate_address,
                           contract_address=contract_address,
                           abi=contract_interface["abi"])

if __name__ == "__main__":
    application.run(host='0.0.0.0', port=80, debug=True)
