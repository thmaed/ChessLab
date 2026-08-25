//
//  _fairymain.h
//  ChessLab/CFairyStockfish
//
//  Point d'entrée renommé (main → _fairy_main) sur le modèle de
//  ``CStockfish/_main.h`` : deux moteurs vivent dans le même binaire d'app,
//  aucun ne peut garder une fonction nommée `main`.
//

#ifndef _fairymain_h
#define _fairymain_h

int _fairy_main(int argc, char* argv[]);

#endif /* _fairymain_h */
