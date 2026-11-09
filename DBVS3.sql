USE RRT;
GO

-- 1. Papildomos paslaugos, kurias teikia TELE2
SELECT pp.papildomosPaslaugosPavadinimas AS paslauga,
       opp.kaina
FROM OperatoriausPapildomaPaslauga opp
JOIN Operatorius o        ON o.operatoriausID = opp.operatoriausID
JOIN PapildomaPaslauga pp ON pp.papildomosPaslaugosID = opp.papildomosPaslaugosID
WHERE UPPER(o.operatoriausPavadinimas) LIKE 'TELE2%'
ORDER BY paslauga;
GO

-- 2. Papildomos paslaugos, kurias siūlo VISI operatoriai
SELECT o.operatoriausPavadinimas         AS operatorius,
       pp.papildomosPaslaugosPavadinimas AS paslauga,
       opp.kaina
FROM OperatoriausPapildomaPaslauga opp
JOIN Operatorius o        ON o.operatoriausID = opp.operatoriausID
JOIN PapildomaPaslauga pp ON pp.papildomosPaslaugosID = opp.papildomosPaslaugosID
WHERE opp.papildomosPaslaugosID IN (
        SELECT papildomosPaslaugosID
        FROM OperatoriausPapildomaPaslauga
        GROUP BY papildomosPaslaugosID
        HAVING COUNT(DISTINCT operatoriausID) = (SELECT COUNT(*) FROM Operatorius)
      )
ORDER BY paslauga, operatorius;
GO

-- 3. Kiekvienai zonai priklausančių valstybių skaičius
SELECT z.zonosPavadinimas   AS zona,
       COUNT(s.saliesKodas) AS valstybiu_skaicius
FROM Zona z
LEFT JOIN Salis s ON s.zonosID = z.zonosID
GROUP BY z.zonosID, z.zonosPavadinimas
ORDER BY zona;
GO

-- 4. Operatorius, siūlantis brangiausius skambučius į Meksiką
SELECT TOP 1 WITH TIES
       o.operatoriausPavadinimas AS operatorius,
       pk.kaina
FROM PaslaugosKainaZonoje pk
JOIN Operatorius o ON o.operatoriausID = pk.operatoriausID
JOIN Salis s       ON s.zonosID        = pk.zonosID
WHERE s.saliesPavadinimas LIKE 'Meksik%'
  AND pk.paslaugosID = 4          -- Skambučiai į užsienio tinklus
ORDER BY pk.kaina DESC;
GO

-- 5. Į mokėjimo planą neįtrauktas interneto planas su mažiausia 1 MB kaina
SELECT TOP 1 WITH TIES
       o.operatoriausPavadinimas AS operatorius,
       ip.intPlanoPavadinimas    AS interneto_planas,
       CAST(ip.kaina / ip.kiekisMB AS DECIMAL(18, 6)) AS kaina_uz_1MB
FROM InternetoPlanas ip
JOIN Operatorius o ON o.operatoriausID = ip.operatoriausID
WHERE ip.kiekisMB > 0
  AND NOT EXISTS (SELECT 1 FROM Planas pl
                  WHERE pl.internetoPlanoID = ip.internetoPlanoID)
ORDER BY ip.kaina / ip.kiekisMB ASC;
GO

-- 6. Abonentų pasiskirstymas tarp operatorių procentais
SELECT o.operatoriausPavadinimas AS operatorius,
       COUNT(a.abonentoID)       AS abonentu_sk,
       CAST(100.0 * COUNT(a.abonentoID) / SUM(COUNT(a.abonentoID)) OVER ()
            AS DECIMAL(5, 2))    AS procentai
FROM Operatorius o
LEFT JOIN Planas pl   ON pl.operatoriausID = o.operatoriausID
LEFT JOIN Abonentas a ON a.planoID = pl.planoID
GROUP BY o.operatoriausID, o.operatoriausPavadinimas
ORDER BY procentai DESC;
GO

-- 7. 3 populiariausi mobiliojo ryšio planai
SELECT TOP 3 WITH TIES
       pl.planoPavadinimas AS planas,
       COUNT(a.abonentoID) AS abonentu_sk
FROM Planas pl
JOIN Abonentas a ON a.planoID = pl.planoID
GROUP BY pl.planoID, pl.planoPavadinimas
ORDER BY abonentu_sk DESC;
GO

-- 8. Dešimties atsitiktinių abonentų informacija
SELECT TOP 10
       asm.vardas + ' ' + asm.pavarde AS pilnas_vardas,
       m.miestoPavadinimas            AS miestas,
       a.numeris,
       a.sutartiesPradzia,
       a.sutartiesPabaiga,
       o.operatoriausPavadinimas      AS operatorius,
       pl.planoPavadinimas            AS planas,
       CASE WHEN EXISTS (SELECT 1 FROM UzsakytasInternetoPlanas uip
                         WHERE uip.abonentoID = a.abonentoID)
            THEN 'Taip' ELSE 'Ne' END AS papildomas_internetas,
       CASE WHEN EXISTS (SELECT 1 FROM UzsakytaPapildomaPaslauga upp
                         WHERE upp.abonentoID = a.abonentoID)
            THEN 'Taip' ELSE 'Ne' END AS papildomos_paslaugos
FROM Abonentas a
JOIN Asmuo asm     ON asm.asmensID = a.asmensID
JOIN Miestas m     ON m.miestoID = asm.miestoID
JOIN Planas pl     ON pl.planoID = a.planoID
JOIN Operatorius o ON o.operatoriausID = pl.operatoriausID
ORDER BY NEWID();
GO

-- 9. TOP 5 abonentai pagal skambučių Lietuvos teritorijoje kiekį 2025 m. spalį
SELECT TOP 5
       asm.vardas + ' ' + asm.pavarde AS abonentas,
       a.numeris,
       COUNT(*) AS skambuciu_sk
FROM RysysP2P r
JOIN Abonentas a ON a.abonentoID = r.abonentoID
JOIN Asmuo asm   ON asm.asmensID = a.asmensID
WHERE r.paslaugosID = 1           -- Skambučiai į Lietuvos tinklus
  AND r.rysioPradzia >= '2025-10-01'
  AND r.rysioPradzia <  '2025-11-01'
GROUP BY a.abonentoID, asm.vardas, asm.pavarde, a.numeris
ORDER BY skambuciu_sk DESC;
GO

-- 10. Populiariausia užsienio šalis pagal skambučių kiekį
SELECT TOP 1 WITH TIES
       s.saliesPavadinimas AS salis,
       COUNT(*)            AS skambuciu_sk
FROM RysysP2P r
JOIN Salis s ON s.saliesKodas = r.adresatoSalis
WHERE r.paslaugosID = 4           -- Skambučiai į užsienio tinklus
GROUP BY s.saliesKodas, s.saliesPavadinimas
ORDER BY skambuciu_sk DESC;
GO
