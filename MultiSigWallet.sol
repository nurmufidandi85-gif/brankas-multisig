// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    // 🏢 EVENT LOG: Catatan riwayat aktivitas brankas di blockchain
    event SetorDana(address indexed pengirim, uint256 jumlah, uint256 saldoSekarang);
    event AjukanTransaksi(address indexed pemilik, uint256 indexed idTx, address indexed tujuan, uint256 nilai);
    event SetujuiTransaksi(address indexed pemilik, uint256 indexed idTx);
    event EksekusiTransaksi(address indexed pemilik, uint256 indexed idTx);
    event BatalkanPersetujuan(address indexed pemilik, uint256 indexed idTx);

    // 📊 STRUKTUR DATA
    address[] public paraPemilik;                  // Daftar dompet bos/pemilik perusahaan
    mapping(address => bool) public isPemilik;     // Cek cepat status kepemilikan dompet
    uint256 public syaratMinimalPersetujuan;        // Angka minimal persetujuan (misal: 2)

    struct Transaksi {
        address tujuan;          // Alamat dompet penerima dana keluar
        uint256 nilai;           // Jumlah koin wei yang akan dikirim
        bool sudahDieksekusi;    // Status apakah uang sudah sukses keluar
        uint256 jumlahSety_Count;// Total tanda tangan persetujuan yang terkumpul
    }

    Transaksi[] public daftarTransaksi;

    // Pemetaan: ID Transaksi => Alamat Pemilik => Status Persetujuan (True/False)
    mapping(uint256 => mapping(address => bool)) public sudahDisetujui;

    // 🛡️ MODIFIER PENGAMAN (Gembok Aturan)
    modifier hanyaPemilik() {
        require(isPemilik[msg.sender], "Bukan Pemilik Sah!");
        _;
    }

    modifier txAda(uint256 _idTx) {
        require(_idTx < daftarTransaksi.length, "ID Transaksi Tidak Ditemukan!");
        _;
    }

    modifier belumDieksekusi(uint256 _idTx) {
        require(!daftarTransaksi[_idTx].sudahDieksekusi, "Transaksi Sudah Selesai!");
        _;
    }

    modifier belumDisetujuiPemilik(uint256 _idTx) {
        require(!sudahDisetujui[_idTx][msg.sender], "Anda Sudah Menandatangani Transaksi Ini!");
        _;
    }

    // 🏗️ CONSTRUCTOR: Inisialisasi daftar bos pemilik saat pertama kali diluncurkan
    constructor(address[] memory _paraPemilik, uint256 _syaratMinimal) {
        require(_paraPemilik.length > 0, "Harus Ada Minimal 1 Pemilik!");
        require(_syaratMinimal > 0 && _syaratMinimal <= _paraPemilik.length, "Syarat Persetujuan Tidak Valid!");

        for (uint256 i = 0; i < _paraPemilik.length; i++) {
            address pemilik = _paraPemilik[i];

            require(pemilik != address(0), "Alamat Dompet Tidak Valid!");
            require(!isPemilik[pemilik], "Alamat Dompet Duplikat!");

            isPemilik[pemilik] = true;
            paraPemilik.push(pemilik);
        }
        syaratMinimalPersetujuan = _syaratMinimal;
    }

    // 💰 FUNGSIONALITAS MENERIMA DANA: Brankas bisa menerima setoran koin otomatis
    receive() external payable {
        emit SetorDana(msg.sender, msg.value, address(this).balance);
    }

    // 📑 1. PROPOSAL: Pemilik mengajukan rencana pengiriman uang keluar
    function ajukanProposalTransaksi(address _tujuan, uint256 _nilai) external hanyaPemilik {
        uint256 idTx = daftarTransaksi.length;

        daftarTransaksi.push(Transaksi({
            tujuan: _tujuan,
            nilai: _nilai,
            sudahDieksekusi: false,
            jumlahSety_Count: 0
        }));

        emit AjukanTransaksi(msg.sender, idTx, _tujuan, _nilai);
    }

    // ✍️ 2. TANDA TANGAN: Pemilik lain memberikan persetujuan (Konfirmasi)
    function setujuiTransaksi(uint256 _idTx) 
        external 
        hanyaPemilik 
        txAda(_idTx) 
        belumDieksekusi(_idTx) 
        belumDisetujuiPemilik(_idTx) 
    {
        Transaksi storage transaksi = daftarTransaksi[_idTx];
        sudahDisetujui[_idTx][msg.sender] = true;
        transaksi.jumlahSety_Count += 1;

        emit SetujuiTransaksi(msg.sender, _idTx);
    }

    // 🚀 3. EKSEKUSI: Jika tanda tangan sudah cukup, dana otomatis meluncur keluar
    function eksekusiTransaksi(uint256 _idTx) external hanyaPemilik txAda(_idTx) belumDieksekusi(_idTx) {
        Transaksi storage transaksi = daftarTransaksi[_idTx];
        
        require(transaksi.jumlahSety_Count >= syaratMinimalPersetujuan, "Tanda Tangan Belum Cukup!");
        require(address(this).balance >= transaksi.nilai, "Saldo Kas Brankas Tidak Cukup!");

        transaksi.sudahDieksekusi = true;
        
        (bool sukses, ) = transaksi.tujuan.call{value: transaksi.nilai}("");
        require(sukses, "Pengiriman Dana Gagal!");

        emit EksekusiTransaksi(msg.sender, _idTx);
    }

    // ❌ BATALKAN: Pemilik menarik kembali tanda tangan jika berubah pikiran
    function batalkanPersetujuan(uint256 _idTx) external hanyaPemilik txAda(_idTx) belumDieksekusi(_idTx) {
        require(sudahDisetujui[_idTx][msg.sender], "Anda Belum Menyetujui Transaksi Ini!");
        
        Transaksi storage transaksi = daftarTransaksi[_idTx];
        sudahDisetujui[_idTx][msg.sender] = false;
        transaksi.jumlahSety_Count -= 1;

        emit BatalkanPersetujuan(msg.sender, _idTx);
    }

    // 📊 FUNGSI PENGECEKAN (Helper)
    function ambilTotalPemilik() external view returns (uint256) {
        return paraPemilik.length;
    }

    function ambilTotalTransaksi() external view returns (uint256) {
        return daftarTransaksi.length;
    }
}
