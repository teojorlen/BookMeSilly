#include <QApplication>
#include "frontend/CalculatorWindow.h"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    
    frontend::CalculatorWindow window;
    window.show();
    
    return app.exec();
}
