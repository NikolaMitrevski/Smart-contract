pragma solidity ^0.4.22;

contract Roulette {
    mapping (address => uint256) public winnings;    
    uint8[] payouts;
    uint8[] numberRange;
    uint public randomNumber;
  
    /* 
    Tipovi opklade(betType) su sledeci:
    0: boja - ulog na crnu ili crvenu boju;
    1: kolona - ulog na 12 broja u jednoj koloni;
    2: trecina(dozen) - ulog na 12 broja, kladjenje na brojeve 1-12 ili 13-24 ili 25-36;
    3: osamnaest - ulog na 18 broja, kladjenje na brojeve 1-18 ili 19-36;
    4: parnost
    5: broj - ulog na jedan broj od 1-37.
        
    U zavisnosti od tipa opklade(betType), broj(number) ce biti:
    0: boja - 0 za crnu, 1 za crvenu;
    1: kolona - 0 za levu, 1 za srednju, 2 za desnu;
    2: trecina(dozen) - 0 za prvu, 1 za drugu, 2 za trecu;
    3: osamnaest - 0 za 1-18, 1 za 19-36;
    4: parnost - 0 za paran, 1 za neparan;
    5: broj - broj.
    */
      
    /* 
    Svaka opkada sastoji se od:
    - javne adrese igraca;
    - tipa oklade;
    - podtipa opklade;
    - vrednosti opklade.
    */
    struct Bet {
        address player;
        uint8 betType;
        uint8 number;
        uint256 betAmount;
    }
    Bet[] public bets;
  
    constructor() public {
        payouts = [2,3,3,2,2,36];
        numberRange = [1,2,2,1,1,36];
    }

    function numberOfBets() public view returns(uint) {
        return (
            bets.length   // broj aktivnih opklada
        );
    }
    
    function bet(uint8 number, uint8 betType) public payable {
        /* 
            Opklada je vazeca ako zadovoljava sledece uslove:
            1 - vrednost opklade(betAmount) je veca od 0.01eth;
            2 - tip opklade(betType) je vazec;
            3 - podtip opklade(number) je vazec;
        */
        require(msg.value >= 10000000000000000, "Vrednost opklade mora biti veæa ili jednaka od 10000000000000000 WEI.");   // 1
        require(betType >= 0 && betType <= 5, "Tip opklade mora biti važeæ.");                                              // 2
        require(number >= 0 && number <= numberRange[betType], "Podtip opklade mora biti važeæ.");                          // 3

        bets.push(Bet({betType: betType, player: msg.sender, number: number, betAmount: msg.value}));
    }
    
    function spinWheel() public {
        // provera da li ima opklada
        require(bets.length > 0, "Broj opklada mora biti veæi od 0.");
        
        // izracunavanje slucajnog(random) broja
        uint diff = block.difficulty;               // vrednost koja govori koliko je tesko pronaci hesh za trenutni blok
        bytes32 hash = blockhash(block.number-1);   // hash od rednog broja prethodnog bloka
        randomNumber = uint(keccak256(abi.encodePacked(diff, hash, bets[bets.length-1].betType, bets[bets.length-1].player, bets[bets.length-1].number))) % 37;
        
        // proverava se svaka opklada i belezi se dobitak
        for (uint i = 0; i < bets.length; i++) {
            bool won = false;
            if (randomNumber == 0) {  
                won = (bets[i].betType == 5 && bets[i].number == 0);                            // opklada na broj 0
            } 
            else {
                if (bets[i].betType == 5) { 
                    won = (bets[i].number == randomNumber);                                     // opklada na broj X
                }
                else if (bets[i].betType == 4) {
                    if (bets[i].number == 0) won = (randomNumber % 2 == 0);                     // opklada na paran broj
                    if (bets[i].number == 1) won = (randomNumber % 2 == 1);                     // opklada na neparan broj
                } 
                else if (bets[i].betType == 3) {            
                    if (bets[i].number == 0) won = (randomNumber <= 18);                        // opklada na brojeve od 1-18
                    if (bets[i].number == 1) won = (randomNumber >= 19);                        // oopklada na brojeve od 19-36
                } 
                else if (bets[i].betType == 2) {                               
                    if (bets[i].number == 0) won = (randomNumber <= 12);                        // opklada na brojeve od 1-12
                    if (bets[i].number == 1) won = (randomNumber > 12 && randomNumber <= 24);   // opklada na brojeve od 13-24
                    if (bets[i].number == 2) won = (randomNumber > 24);                         // opklada na brojeve od 25-36
                } 
                else if (bets[i].betType == 1) {               
                    if (bets[i].number == 0) won = (randomNumber % 3 == 1);                     // opklada na levu kolonu
                    if (bets[i].number == 1) won = (randomNumber % 3 == 2);                     // opklada na srednju kolonu
                    if (bets[i].number == 2) won = (randomNumber % 3 == 0);                     // opklada na desnu kolonu
                } 
                else if (bets[i].betType == 0) {
                    if (bets[i].number == 0) {                                                  // opklada na crnu broj
                        if (randomNumber <= 10 || (randomNumber >= 20 && randomNumber <= 28)) {
                            won = (randomNumber % 2 == 0);
                        } 
                        else {
                            won = (randomNumber % 2 == 1);
                        }
                    } 
                    else {                                                                      // opklada na crven broj
                        if (randomNumber <= 10 || (randomNumber >= 20 && randomNumber <= 28)) {
                            won = (randomNumber % 2 == 1);
                        } 
                        else {
                            won = (randomNumber % 2 == 0);
                        }
                    }
                }
            }
            // ako je opklada dobijena, belezi se dobitak za igraca koji je dobio 
            if (won) {
                winnings[bets[i].player] += bets[i].betAmount * payouts[bets[i].betType];
            }
        }
        
        // brisu se sve opklade
        delete bets;
    }
    
    // funkcija koja isplacuje igraca ukoliko je dobitnik
    function cashOut() public {
        require(winnings[msg.sender] > 0, "Nema pobednika.");
        
        uint256 amount = winnings[msg.sender];
        
        winnings[msg.sender] = 0;
        
        msg.sender.transfer(amount);
    }
}
