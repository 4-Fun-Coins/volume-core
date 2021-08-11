class Category {
    name;
    address;
    number;

    constructor(newCategory) {
        this.name = newCategory[0];
        this.address = newCategory[1];
        this.number = newCategory[2];
    }
}

module.exports = {
    Category
}