#include "frontend/CalculatorWindow.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGridLayout>
#include <QWidget>
#include <QFont>
#include <QMessageBox>

namespace frontend {

CalculatorWindow::CalculatorWindow(QWidget *parent)
    : QMainWindow(parent), firstOperand(0), shouldResetDisplay(false) {
    setWindowTitle("Calculator");
    setGeometry(100, 100, 400, 500);
    
    setupUI();
}

CalculatorWindow::~CalculatorWindow() {
}

void CalculatorWindow::setupUI() {
    QWidget *centralWidget = new QWidget(this);
    setCentralWidget(centralWidget);
    
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);
    mainLayout->setSpacing(10);
    mainLayout->setContentsMargins(10, 10, 10, 10);
    
    // Display
    display = new QLineEdit(this);
    display->setReadOnly(true);
    display->setText("0");
    display->setAlignment(Qt::AlignRight);
    QFont displayFont = display->font();
    displayFont.setPointSize(24);
    display->setFont(displayFont);
    display->setMinimumHeight(60);
    mainLayout->addWidget(display);
    
    // Buttons grid
    QGridLayout *gridLayout = new QGridLayout();
    gridLayout->setSpacing(5);
    
    // Clear and Delete buttons
    clearButton = new QPushButton("C", this);
    deleteButton = new QPushButton("DEL", this);
    gridLayout->addWidget(clearButton, 0, 0, 1, 2);
    gridLayout->addWidget(deleteButton, 0, 2, 1, 2);
    
    connect(clearButton, &QPushButton::clicked, this, &CalculatorWindow::onClearClicked);
    connect(deleteButton, &QPushButton::clicked, this, &CalculatorWindow::onDeleteClicked);
    
    // Number buttons
    createButtons();
    
    // Operations
    divideButton = new QPushButton("/", this);
    multiplyButton = new QPushButton("*", this);
    subtractButton = new QPushButton("-", this);
    addButton = new QPushButton("+", this);
    equalsButton = new QPushButton("=", this);
    
    gridLayout->addWidget(digitButtons[7], 1, 0);
    gridLayout->addWidget(digitButtons[8], 1, 1);
    gridLayout->addWidget(digitButtons[9], 1, 2);
    gridLayout->addWidget(divideButton, 1, 3);
    
    gridLayout->addWidget(digitButtons[4], 2, 0);
    gridLayout->addWidget(digitButtons[5], 2, 1);
    gridLayout->addWidget(digitButtons[6], 2, 2);
    gridLayout->addWidget(multiplyButton, 2, 3);
    
    gridLayout->addWidget(digitButtons[1], 3, 0);
    gridLayout->addWidget(digitButtons[2], 3, 1);
    gridLayout->addWidget(digitButtons[3], 3, 2);
    gridLayout->addWidget(subtractButton, 3, 3);
    
    gridLayout->addWidget(digitButtons[0], 4, 0, 1, 2);
    gridLayout->addWidget(addButton, 4, 2);
    gridLayout->addWidget(equalsButton, 4, 3);
    
    // Set button sizes
    for (int i = 0; i < 10; ++i) {
        digitButtons[i]->setMinimumHeight(50);
    }
    clearButton->setMinimumHeight(50);
    deleteButton->setMinimumHeight(50);
    divideButton->setMinimumHeight(50);
    multiplyButton->setMinimumHeight(50);
    subtractButton->setMinimumHeight(50);
    addButton->setMinimumHeight(50);
    equalsButton->setMinimumHeight(50);
    
    // Connect operations
    connect(divideButton, &QPushButton::clicked, [this]() { onOperationClicked("/"); });
    connect(multiplyButton, &QPushButton::clicked, [this]() { onOperationClicked("*"); });
    connect(subtractButton, &QPushButton::clicked, [this]() { onOperationClicked("-"); });
    connect(addButton, &QPushButton::clicked, [this]() { onOperationClicked("+"); });
    connect(equalsButton, &QPushButton::clicked, this, &CalculatorWindow::onEqualsClicked);
    
    mainLayout->addLayout(gridLayout);
}

void CalculatorWindow::createButtons() {
    for (int i = 0; i < 10; ++i) {
        digitButtons[i] = new QPushButton(QString::number(i), this);
        int digit = i;
        connect(digitButtons[i], &QPushButton::clicked, [this, digit]() {
            onDigitClicked(digit);
        });
    }
}

void CalculatorWindow::onDigitClicked(int digit) {
    if (shouldResetDisplay) {
        currentInput = QString::number(digit);
        shouldResetDisplay = false;
    } else {
        if (currentInput == "0") {
            currentInput = QString::number(digit);
        } else {
            currentInput += QString::number(digit);
        }
    }
    updateDisplay();
}

void CalculatorWindow::onOperationClicked(const QString &op) {
    if (!currentOperation.isEmpty() && !shouldResetDisplay) {
        onEqualsClicked();
    }
    
    bool ok;
    firstOperand = currentInput.toInt(&ok);
    currentOperation = op;
    currentInput = "";
    shouldResetDisplay = true;
}

void CalculatorWindow::onEqualsClicked() {
    if (currentOperation.isEmpty()) {
        return;
    }
    
    bool ok;
    int secondOperand = currentInput.toInt(&ok);
    
    try {
        int result = 0;
        
        if (currentOperation == "+") {
            result = calculator.add(firstOperand, secondOperand);
        } else if (currentOperation == "-") {
            result = calculator.subtract(firstOperand, secondOperand);
        } else if (currentOperation == "*") {
            result = calculator.multiply(firstOperand, secondOperand);
        } else if (currentOperation == "/") {
            result = calculator.divide(firstOperand, secondOperand);
        }
        
        currentInput = QString::number(result);
        currentOperation = "";
        shouldResetDisplay = true;
        updateDisplay();
    } catch (const std::exception &e) {
        QMessageBox::critical(this, "Error", QString::fromStdString(e.what()));
        onClearClicked();
    }
}

void CalculatorWindow::onClearClicked() {
    currentInput = "0";
    currentOperation = "";
    firstOperand = 0;
    shouldResetDisplay = false;
    updateDisplay();
}

void CalculatorWindow::onDeleteClicked() {
    if (currentInput.length() > 1) {
        currentInput.chop(1);
    } else {
        currentInput = "0";
    }
    updateDisplay();
}

void CalculatorWindow::updateDisplay() {
    display->setText(currentInput);
}

}  // namespace frontend
