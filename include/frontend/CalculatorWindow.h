#ifndef FRONTEND_CALCULATORWINDOW_H
#define FRONTEND_CALCULATORWINDOW_H

#include <QMainWindow>
#include <QLineEdit>
#include <QPushButton>
#include <QLabel>
#include "backend/Calculator.h"

namespace frontend {

class CalculatorWindow : public QMainWindow {
    Q_OBJECT

public:
    CalculatorWindow(QWidget *parent = nullptr);
    ~CalculatorWindow();

private slots:
    void onDigitClicked(int digit);
    void onOperationClicked(const QString &op);
    void onEqualsClicked();
    void onClearClicked();
    void onDeleteClicked();

private:
    void updateDisplay();
    void setupUI();
    void createButtons();

    QLineEdit *display;
    QPushButton *digitButtons[10];
    QPushButton *addButton;
    QPushButton *subtractButton;
    QPushButton *multiplyButton;
    QPushButton *divideButton;
    QPushButton *equalsButton;
    QPushButton *clearButton;
    QPushButton *deleteButton;

    backend::Calculator calculator;
    QString currentInput;
    QString currentOperation;
    int firstOperand;
    bool shouldResetDisplay;
};

}  // namespace frontend

#endif  // FRONTEND_CALCULATORWINDOW_H
