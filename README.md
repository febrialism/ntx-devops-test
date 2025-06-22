# Build Simple CI/CD using Jenkins and Environment Provision with Ansible.

Selamat Pagi Pak Hafidz, Bu Yulia dan Tim.
Terima kasih sebelumnya sudah reach lamaran saya, memberikan saya waktu tambahan dan kesempatan saya untuk ikut Test.

Izin menjelaskan tentang solusi test dari saya, dengan catatan
1. Nenggunakan Environment Local Lab, dengan setup services All-in-One dalam satu VM (Jenkins, Docker, NodeJs & Nginx LB).
2. Menggunakan Claude untuk menyelesaikan Test ini.

Kedua poin diatas perlu saya lakukan untuk mempersingkat waktu, karena saya hanya bisa melakukannya diweekend ini, dari malam hari ke pagi. Ditambah saya belum familiar, karena masih belajar dan switch dari Infrastructure Engineer ke DevOps.

Berikut untuk Topologinya.

Untuk Flow CI/CDnya sebagai berikut :
1. Checkout secara berkala ke Repo tiap 2 menit.
2. Install Depedencies untuk build dan run node app test.
3. Build docker image.
4. Stop existing container (Jika ada).
5. Deploy first container.
6. Verify apakah container bisa di curl dan mendapat respon HTTP 200.
7. Deploy second container.
8. Pipeline selesai dan cleanup old images docker (keep 5 images).

Semuanya saya test secara manual terlebih dahulu, baru saya buat pipelines and ansible playbook untuk provisioning VMnya. Itu kenapa banyak commit terjadi di repo untuk try and error.

Untuk Ansible playbook saya simpan di branch Ansible dan untuk Demonya saya upload via Youtube https://youtu.be/8w4VPUnW4ic. Playbook menggunakan repository community dan compatible dengan RHEL 8 like seperti Rocky, CentOS, Alma dan lain-lain.

Sekian jawaban test dari saya, sebelumnya saya ucapkan terima kasih banyak atas kesempatannya.



